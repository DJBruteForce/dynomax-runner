Set-StrictMode -Version Latest

function New-DynomaxTestRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][string]$ProjectKey,
        [Parameter(Mandatory)][string]$WorkflowKey,
        [Parameter(Mandatory)][string]$EnvironmentKey,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$PackageHash
    )
    $runId = [Guid]::NewGuid()
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.TestRun(RunId,ProjectId,WorkflowVersionId,MachineName,EnvironmentKey,Status,StartedAtUtc,WorkingDirectory,PackageHash)
SELECT @RunId,p.ProjectId,wv.WorkflowVersionId,@MachineName,@EnvironmentKey,'RUNNING',SYSUTCDATETIME(),@WorkingDirectory,@PackageHash
FROM dmx.Project p
JOIN dmx.Workflow w ON w.ProjectId=p.ProjectId AND w.WorkflowKey=@WorkflowKey
JOIN dmx.WorkflowVersion wv ON wv.WorkflowId=w.WorkflowId AND wv.IsCurrent=1
WHERE p.ProjectKey=@ProjectKey;
'@ -Parameters @{ '@RunId'=$runId; '@MachineName'=$env:COMPUTERNAME; '@EnvironmentKey'=$EnvironmentKey; '@WorkingDirectory'=$WorkingDirectory; '@PackageHash'=$PackageHash; '@WorkflowKey'=$WorkflowKey; '@ProjectKey'=$ProjectKey })
        $exists = Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT COUNT(*) FROM dmx.TestRun WHERE RunId=@RunId;' -Parameters @{ '@RunId'=$runId }
        if ([int]$exists -ne 1) { throw 'Could not create TestRun. Confirm project and workflow were imported.' }
        return $runId
    }
    finally { $connection.Dispose() }
}

function Complete-DynomaxTestRun {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)][string]$Status,[string]$Summary)
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
UPDATE dmx.TestRun SET Status=@Status,EndedAtUtc=SYSUTCDATETIME(),Summary=@Summary WHERE RunId=@RunId;
'@ -Parameters @{ '@Status'=$Status; '@Summary'=$(if($Summary){$Summary}else{[DBNull]::Value}); '@RunId'=$RunId })
    }
    finally { $connection.Dispose() }
}

function Add-DynomaxActionRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$ActionKey,[Parameter(Mandatory)][string]$Status,[string]$Message,[string]$OutputJson,
        [bool]$IsCleanup=$false
    )
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $inserted=Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,@StepOrder,av.ActionVersionId,@ActionKey,@Status,@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,@OutputJson
FROM dmx.TestRun tr
JOIN dmx.Action a ON a.ProjectId=tr.ProjectId AND a.ActionKey=@ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.IsCurrent=1
WHERE tr.RunId=@RunId;
'@ -Parameters @{ '@RunId'=$RunId; '@StepOrder'=$StepOrder; '@ActionKey'=$ActionKey; '@Status'=$Status; '@IsCleanup'=$IsCleanup; '@Message'=$(if($Message){$Message}else{[DBNull]::Value}); '@OutputJson'=$(if($OutputJson){$OutputJson}else{[DBNull]::Value}) }
        if([int]$inserted -ne 1){throw "Could not persist action result for '$ActionKey' in run '$RunId'."}
    }
    finally { $connection.Dispose() }
}

function Set-DynomaxContextValuesInSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)]$Context)
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        foreach ($property in $Context.values.PSObject.Properties) {
            $valueJson = ([ordered]@{ value = $property.Value }) | ConvertTo-Json -Depth 50 -Compress
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
MERGE dmx.RunContextValue AS target
USING (SELECT @RunId AS RunId,@ContextKey AS ContextKey) AS source
ON target.RunId=source.RunId AND target.ContextKey=source.ContextKey
WHEN MATCHED THEN UPDATE SET ValueJson=@ValueJson,UpdatedAtUtc=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(RunContextValueId,RunId,ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc)
VALUES(NEWID(),@RunId,@ContextKey,@ValueJson,0,SYSUTCDATETIME(),SYSUTCDATETIME());
'@ -Parameters @{ '@RunId'=$RunId; '@ContextKey'=[string]$property.Name; '@ValueJson'=$valueJson })
        }
    }
    finally { $connection.Dispose() }
}

function Add-DynomaxArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId,[string]$ActionKey,
        [Parameter(Mandatory)][string]$ArtifactType,[Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][long]$MaximumBytes
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt $MaximumBytes) { return $null }
    [byte[]]$original = [System.IO.File]::ReadAllBytes($Path)
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $memory = New-Object System.IO.MemoryStream
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($memory,[System.IO.Compression.CompressionMode]::Compress,$true)
        try { $gzip.Write($original,0,$original.Length) } finally { $gzip.Dispose() }
        [byte[]]$compressed = $memory.ToArray()
    }
    finally { $memory.Dispose() }
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $contentIdText = Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT CONVERT(nvarchar(36),ArtifactContentId) FROM dmx.ArtifactContent WHERE Sha256=@Sha256;' -Parameters @{ '@Sha256'=$hash }
        if (-not $contentIdText) {
            $contentId=[Guid]::NewGuid()
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.ArtifactContent(ArtifactContentId,Sha256,OriginalLength,StoredLength,CompressionType,Content,CreatedAtUtc)
VALUES(@Id,@Sha256,@OriginalLength,@StoredLength,'GZip',@Content,SYSUTCDATETIME());
'@ -Parameters @{ '@Id'=$contentId; '@Sha256'=$hash; '@OriginalLength'=[long]$original.LongLength; '@StoredLength'=[long]$compressed.LongLength; '@Content'=$compressed })
        } else { $contentId=[Guid]$contentIdText }
        $artifactId=[Guid]::NewGuid()
        [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.Artifact(ArtifactId,RunId,ActionKey,ArtifactContentId,ArtifactType,OriginalFileName,MimeType,CreatedAtUtc)
VALUES(@Id,@RunId,@ActionKey,@ContentId,@ArtifactType,@FileName,@MimeType,SYSUTCDATETIME());
'@ -Parameters @{ '@Id'=$artifactId; '@RunId'=$RunId; '@ActionKey'=$(if($ActionKey){$ActionKey}else{[DBNull]::Value}); '@ContentId'=$contentId; '@ArtifactType'=$ArtifactType; '@FileName'=$file.Name; '@MimeType'=(Get-DynomaxMimeType -Path $Path) })
        return $artifactId
    }
    finally { $connection.Dispose() }
}

function Get-DynomaxMimeType {
    param([Parameter(Mandatory)][string]$Path)
    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.json' { 'application/json' }
        '.xml' { 'application/xml' }
        '.html' { 'text/html' }
        '.htm' { 'text/html' }
        '.md' { 'text/markdown' }
        '.txt' { 'text/plain' }
        '.log' { 'text/plain' }
        '.png' { 'image/png' }
        '.jpg' { 'image/jpeg' }
        '.jpeg' { 'image/jpeg' }
        '.zip' { 'application/zip' }
        default { 'application/octet-stream' }
    }
}

function Get-DynomaxOverallStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId)
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $rows = Invoke-DynomaxSqlRows -Connection $connection -CommandText 'SELECT Status,IsCleanup FROM dmx.ActionRun WHERE RunId=@RunId;' -Parameters @{ '@RunId'=$RunId }
        if ($rows.Rows.Count -eq 0) { return 'ERROR' }
        $statuses = @($rows.Rows | ForEach-Object { [string]$_.Status })
        $severity = @('ERROR','CLEANUP_FAILED','TEST_INVALID','STALE','FAIL','BLOCKED','SKIPPED','PASS')
        foreach ($candidate in $severity) { if ($statuses -contains $candidate) { return $candidate } }
        return 'ERROR'
    }
    finally { $connection.Dispose() }
}

function Get-DynomaxFirstProblem {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId)

    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $table = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT TOP (1) StepOrder,ActionKey,Status,Message
FROM dmx.ActionRun
WHERE RunId=@RunId AND Status NOT IN ('PASS','SKIPPED')
ORDER BY StepOrder,StartedAtUtc;
'@ -Parameters @{ '@RunId'=$RunId }

        if ($table.Rows.Count -eq 0) { return $null }
        $row = $table.Rows[0]
        return [pscustomobject]@{
            StepOrder = [int]$row.StepOrder
            ActionKey = [string]$row.ActionKey
            Status = [string]$row.Status
            Message = [string]$row.Message
        }
    }
    finally { $connection.Dispose() }
}

function Export-DynomaxRunSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)][string]$OutputDirectory)
    Ensure-DynomaxDirectory -Path $OutputDirectory | Out-Null
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $run = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT tr.RunId,p.ProjectKey,w.WorkflowKey,tr.EnvironmentKey,tr.Status,tr.StartedAtUtc,tr.EndedAtUtc,tr.MachineName,tr.Summary
FROM dmx.TestRun tr JOIN dmx.Project p ON p.ProjectId=tr.ProjectId
LEFT JOIN dmx.WorkflowVersion wv ON wv.WorkflowVersionId=tr.WorkflowVersionId
LEFT JOIN dmx.Workflow w ON w.WorkflowId=wv.WorkflowId
WHERE tr.RunId=@RunId;
'@ -Parameters @{ '@RunId'=$RunId }
        $actions = Invoke-DynomaxSqlRows -Connection $connection -CommandText 'SELECT StepOrder,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson FROM dmx.ActionRun WHERE RunId=@RunId ORDER BY StepOrder,StartedAtUtc;' -Parameters @{ '@RunId'=$RunId }
        $runRow = $run.Rows[0]
        $result = [ordered]@{
            schemaVersion=1; runId=[string]$runRow.RunId; projectKey=[string]$runRow.ProjectKey; workflowKey=[string]$runRow.WorkflowKey
            environment=[string]$runRow.EnvironmentKey; status=[string]$runRow.Status; machine=[string]$runRow.MachineName
            startedAtUtc=[string]$runRow.StartedAtUtc; endedAtUtc=[string]$runRow.EndedAtUtc; summary=[string]$runRow.Summary
            actions=@($actions.Rows | ForEach-Object { [ordered]@{ stepOrder=[int]$_.StepOrder; actionId=[string]$_.ActionKey; status=[string]$_.Status; cleanup=[bool]$_.IsCleanup; message=[string]$_.Message; outputJson=[string]$_.OutputJson } })
        }
        $jsonPath=Join-Path $OutputDirectory 'RunSummary.json'
        Write-DynomaxJson -Value $result -Path $jsonPath
        $lines=@("# Dynomax Run $RunId",'',"- Project: $($result.projectKey)","- Workflow: $($result.workflowKey)","- Environment: $($result.environment)","- Status: $($result.status)","- Machine: $($result.machine)",'','## Actions','')
        foreach($a in $result.actions){$lines += "- [$($a.status)] $($a.stepOrder) - $($a.actionId)$(if($a.cleanup){' (cleanup)'})"; if($a.message){$lines += "  - $($a.message -replace "`r?`n",' ')"}}
        [System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'RunSummary.md'),$lines,(New-Object System.Text.UTF8Encoding($false)))
        return $result
    }
    finally { $connection.Dispose() }
}

function Set-DynomaxClipboardFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Clipboard file does not exist: $fullPath"
    }

    $setClipboard = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
    if ($setClipboard -and $setClipboard.Parameters.ContainsKey('Path')) {
        Set-Clipboard -Path $fullPath
        return
    }

    Add-Type -AssemblyName System.Windows.Forms
    $files = New-Object System.Collections.Specialized.StringCollection
    [void]$files.Add($fullPath)
    $data = New-Object System.Windows.Forms.DataObject
    $data.SetFileDropList($files)
    [System.Windows.Forms.Clipboard]::SetDataObject($data, $true)
}

