Set-StrictMode -Version Latest

function New-DynomaxTestRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][string]$ProjectKey,
        [Parameter(Mandatory)][string]$WorkflowKey,
        [Parameter(Mandatory)][string]$EnvironmentKey,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$PackageHash,
        [Guid]$WorkflowVersionId = [Guid]::Empty
    )
    $runId = [Guid]::NewGuid()
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        if ($WorkflowVersionId -ne [Guid]::Empty) {
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.TestRun(RunId,ProjectId,WorkflowVersionId,MachineName,EnvironmentKey,Status,StartedAtUtc,WorkingDirectory,PackageHash)
SELECT @RunId,p.ProjectId,wv.WorkflowVersionId,@MachineName,@EnvironmentKey,'RUNNING',SYSUTCDATETIME(),@WorkingDirectory,@PackageHash
FROM dmx.Project p
JOIN dmx.Workflow w ON w.ProjectId=p.ProjectId AND w.WorkflowKey=@WorkflowKey
JOIN dmx.WorkflowVersion wv ON wv.WorkflowId=w.WorkflowId AND wv.WorkflowVersionId=@WorkflowVersionId
WHERE p.ProjectKey=@ProjectKey;
'@ -Parameters @{
                '@RunId'=$runId
                '@MachineName'=$env:COMPUTERNAME
                '@EnvironmentKey'=$EnvironmentKey
                '@WorkingDirectory'=$WorkingDirectory
                '@PackageHash'=$PackageHash
                '@WorkflowKey'=$WorkflowKey
                '@ProjectKey'=$ProjectKey
                '@WorkflowVersionId'=$WorkflowVersionId
            })
        }
        else {
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.TestRun(RunId,ProjectId,WorkflowVersionId,MachineName,EnvironmentKey,Status,StartedAtUtc,WorkingDirectory,PackageHash)
SELECT @RunId,p.ProjectId,wv.WorkflowVersionId,@MachineName,@EnvironmentKey,'RUNNING',SYSUTCDATETIME(),@WorkingDirectory,@PackageHash
FROM dmx.Project p
JOIN dmx.Workflow w ON w.ProjectId=p.ProjectId AND w.WorkflowKey=@WorkflowKey
JOIN dmx.WorkflowVersion wv ON wv.WorkflowId=w.WorkflowId AND wv.IsCurrent=1
WHERE p.ProjectKey=@ProjectKey;
'@ -Parameters @{
                '@RunId'=$runId
                '@MachineName'=$env:COMPUTERNAME
                '@EnvironmentKey'=$EnvironmentKey
                '@WorkingDirectory'=$WorkingDirectory
                '@PackageHash'=$PackageHash
                '@WorkflowKey'=$WorkflowKey
                '@ProjectKey'=$ProjectKey
            })
        }
        $exists = Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT COUNT(*) FROM dmx.TestRun WHERE RunId=@RunId;' -Parameters @{ '@RunId'=$runId }
        if ([int]$exists -ne 1) { throw 'Could not create TestRun. Confirm the project and exact workflow version were imported.' }
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
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][string]$Status,
        [string]$Message,
        [string]$OutputJson,
        [bool]$IsCleanup=$false,
        [Guid]$ActionVersionId = [Guid]::Empty,
        [switch]$AllowUnresolvedActionVersion
    )
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $parameters = @{
            '@RunId'=$RunId
            '@StepOrder'=$StepOrder
            '@ActionKey'=$ActionKey
            '@Status'=$Status
            '@IsCleanup'=$IsCleanup
            '@Message'=$(if($Message){$Message}else{[DBNull]::Value})
            '@OutputJson'=$(if($OutputJson){$OutputJson}else{[DBNull]::Value})
        }

        if ($ActionVersionId -ne [Guid]::Empty) {
            $parameters['@ActionVersionId'] = $ActionVersionId
            $inserted=Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,@StepOrder,av.ActionVersionId,@ActionKey,@Status,@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,@OutputJson
FROM dmx.TestRun tr
JOIN dmx.Action a ON a.ProjectId=tr.ProjectId AND a.ActionKey=@ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.ActionVersionId=@ActionVersionId
WHERE tr.RunId=@RunId;
'@ -Parameters $parameters
        }
        elseif ($AllowUnresolvedActionVersion) {
            $inserted=Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,@StepOrder,NULL,@ActionKey,@Status,@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,@OutputJson
FROM dmx.TestRun tr
WHERE tr.RunId=@RunId;
'@ -Parameters $parameters
        }
        else {
            $inserted=Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,@StepOrder,av.ActionVersionId,@ActionKey,@Status,@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,@OutputJson
FROM dmx.TestRun tr
JOIN dmx.Action a ON a.ProjectId=tr.ProjectId AND a.ActionKey=@ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.IsCurrent=1
WHERE tr.RunId=@RunId;
'@ -Parameters $parameters
        }

        if([int]$inserted -ne 1){throw "Could not persist action result for '$ActionKey' in run '$RunId'."}
    }
    finally { $connection.Dispose() }
}

function Set-DynomaxContextValuesInSql {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig,[Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)]$Context)
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $secretLookup=@{}
        foreach($secretKey in @(Get-DynomaxPropertyValue -Object $Context -Name 'secretKeys' -DefaultValue @())){
            if(-not [string]::IsNullOrWhiteSpace([string]$secretKey)){$secretLookup[[string]$secretKey]=$true}
        }
        foreach ($property in $Context.values.PSObject.Properties) {
            $isSecret=$secretLookup.ContainsKey([string]$property.Name)
            $valueJson=$(if($isSecret){'{"redacted":true}'}else{([ordered]@{ value = $property.Value }) | ConvertTo-Json -Depth 50 -Compress})
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
MERGE dmx.RunContextValue AS target
USING (SELECT @RunId AS RunId,@ContextKey AS ContextKey) AS source
ON target.RunId=source.RunId AND target.ContextKey=source.ContextKey
WHEN MATCHED THEN UPDATE SET ValueJson=@ValueJson,IsSecret=@IsSecret,UpdatedAtUtc=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(RunContextValueId,RunId,ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc)
VALUES(NEWID(),@RunId,@ContextKey,@ValueJson,@IsSecret,SYSUTCDATETIME(),SYSUTCDATETIME());
'@ -Parameters @{ '@RunId'=$RunId; '@ContextKey'=[string]$property.Name; '@ValueJson'=$valueJson; '@IsSecret'=[bool]$isSecret })
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


function ConvertFrom-DynomaxDbJson {
    [CmdletBinding()]
    param($Value)
    if ($null -eq $Value -or $Value -is [DBNull]) { return $null }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    try { return ($text | ConvertFrom-Json) } catch { return $text }
}

function ConvertTo-DynomaxNullableString {
    [CmdletBinding()]
    param($Value)
    if ($null -eq $Value -or $Value -is [DBNull]) { return $null }
    return [string]$Value
}

function Export-DynomaxRunSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$OutputDirectory
    )

    Ensure-DynomaxDirectory -Path $OutputDirectory | Out-Null
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $runTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT tr.RunId,tr.WorkflowVersionId,p.ProjectKey,p.DisplayName AS ProjectName,w.WorkflowKey,w.DisplayName AS WorkflowName,
       wv.VersionNumber AS WorkflowVersion,wv.DefinitionHash AS WorkflowDefinitionHash,
       tr.EnvironmentKey,tr.Status,tr.StartedAtUtc,tr.EndedAtUtc,tr.MachineName,tr.Summary,
       tr.PackageHash,tr.WorkingDirectory
FROM dmx.TestRun tr
JOIN dmx.Project p ON p.ProjectId=tr.ProjectId
LEFT JOIN dmx.WorkflowVersion wv ON wv.WorkflowVersionId=tr.WorkflowVersionId
LEFT JOIN dmx.Workflow w ON w.WorkflowId=wv.WorkflowId
WHERE tr.RunId=@RunId;
'@ -Parameters @{ '@RunId'=$RunId }
        if ($runTable.Rows.Count -ne 1) { throw "Run '$RunId' was not found." }

        $actionTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT ar.ActionRunId,ar.ActionVersionId,ar.StepOrder,ar.ActionKey,ar.Status,ar.IsCleanup,ar.StartedAtUtc,ar.EndedAtUtc,
       ar.Message,ar.OutputJson,av.VersionNumber AS ActionVersion,av.Engine,av.EntryPoint,
       av.DefinitionHash,av.ImplementationHash,ws.RequestedActionVersion
FROM dmx.ActionRun ar
JOIN dmx.TestRun tr ON tr.RunId=ar.RunId
LEFT JOIN dmx.ActionVersion av ON av.ActionVersionId=ar.ActionVersionId
OUTER APPLY(
    SELECT TOP (1) step.RequestedActionVersion
    FROM dmx.WorkflowStep step
    WHERE step.WorkflowVersionId=tr.WorkflowVersionId
      AND step.StepOrder=ar.StepOrder
      AND step.ActionKey=ar.ActionKey
      AND step.IsCleanup=ar.IsCleanup
    ORDER BY step.WorkflowStepId
) ws
WHERE ar.RunId=@RunId
ORDER BY ar.StepOrder,ar.StartedAtUtc;
'@ -Parameters @{ '@RunId'=$RunId }

        $contextTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT ContextKey,ValueJson,CreatedAtUtc,UpdatedAtUtc
FROM dmx.RunContextValue
WHERE RunId=@RunId AND IsSecret=0
ORDER BY ContextKey;
'@ -Parameters @{ '@RunId'=$RunId }

        $assertionTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT a.AssertionId,ar.StepOrder,ar.ActionKey,a.AssertionName,a.ExpectedValue,a.ActualValue,a.Passed,a.CreatedAtUtc
FROM dmx.Assertion a
JOIN dmx.ActionRun ar ON ar.ActionRunId=a.ActionRunId
WHERE ar.RunId=@RunId
ORDER BY ar.StepOrder,a.CreatedAtUtc;
'@ -Parameters @{ '@RunId'=$RunId }

        $eventTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT e.RunEventId,ar.StepOrder,ar.ActionKey,e.EventLevel,e.EventType,e.Message,e.DataJson,e.CreatedAtUtc
FROM dmx.RunEvent e
LEFT JOIN dmx.ActionRun ar ON ar.ActionRunId=e.ActionRunId
WHERE e.RunId=@RunId
ORDER BY e.CreatedAtUtc;
'@ -Parameters @{ '@RunId'=$RunId }

        $cleanupTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT cr.CleanupRegistrationId,cr.CleanupActionKey,cr.ObjectType,cr.ObjectIdentifier,cr.RegistrationJson,
       cr.CreatedAtUtc,cu.CleanupRunId,cu.Status,cu.StartedAtUtc,cu.EndedAtUtc,cu.Message
FROM dmx.CleanupRegistration cr
LEFT JOIN dmx.CleanupRun cu ON cu.CleanupRegistrationId=cr.CleanupRegistrationId
WHERE cr.RunId=@RunId
ORDER BY cr.CreatedAtUtc,cu.StartedAtUtc;
'@ -Parameters @{ '@RunId'=$RunId }

        $artifactTable = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT a.ArtifactId,a.ActionKey,a.ArtifactType,a.OriginalFileName,a.MimeType,a.CreatedAtUtc,
       c.Sha256,c.OriginalLength,c.StoredLength,c.CompressionType
FROM dmx.Artifact a
JOIN dmx.ArtifactContent c ON c.ArtifactContentId=a.ArtifactContentId
WHERE a.RunId=@RunId
ORDER BY a.CreatedAtUtc,a.OriginalFileName;
'@ -Parameters @{ '@RunId'=$RunId }

        $runRow = $runTable.Rows[0]
        $actions = @($actionTable.Rows | ForEach-Object {
            $duration = $null
            if (-not ($_.EndedAtUtc -is [DBNull]) -and -not ($_.StartedAtUtc -is [DBNull])) {
                $duration = [long](([datetime]$_.EndedAtUtc - [datetime]$_.StartedAtUtc).TotalMilliseconds)
            }
            [ordered]@{
                actionRunId=[string]$_.ActionRunId
                actionVersionId=$(if($_.ActionVersionId -is [DBNull]){$null}else{[string]$_.ActionVersionId})
                stepOrder=[int]$_.StepOrder
                actionId=[string]$_.ActionKey
                requestedActionVersion=$(if($_.RequestedActionVersion -is [DBNull]){$null}else{[int]$_.RequestedActionVersion})
                resolvedActionVersion=$(if($_.ActionVersion -is [DBNull]){$null}else{[int]$_.ActionVersion})
                actionVersion=$(if($_.ActionVersion -is [DBNull]){$null}else{[int]$_.ActionVersion})
                engine=ConvertTo-DynomaxNullableString $_.Engine
                entryPoint=ConvertTo-DynomaxNullableString $_.EntryPoint
                definitionHash=ConvertTo-DynomaxNullableString $_.DefinitionHash
                implementationHash=ConvertTo-DynomaxNullableString $_.ImplementationHash
                status=[string]$_.Status
                cleanup=[bool]$_.IsCleanup
                startedAtUtc=[string]$_.StartedAtUtc
                endedAtUtc=ConvertTo-DynomaxNullableString $_.EndedAtUtc
                durationMs=$duration
                message=ConvertTo-DynomaxNullableString $_.Message
                output=ConvertFrom-DynomaxDbJson $_.OutputJson
            }
        })

        $context = [ordered]@{}
        foreach ($row in $contextTable.Rows) {
            $parsed = ConvertFrom-DynomaxDbJson $row.ValueJson
            if ($null -ne $parsed -and $parsed.PSObject.Properties.Name -contains 'value') {
                $context[[string]$row.ContextKey] = $parsed.value
            }
            else { $context[[string]$row.ContextKey] = $parsed }
        }

        $assertions = @($assertionTable.Rows | ForEach-Object {
            [ordered]@{
                assertionId=[string]$_.AssertionId
                stepOrder=[int]$_.StepOrder
                actionId=[string]$_.ActionKey
                name=[string]$_.AssertionName
                expected=ConvertTo-DynomaxNullableString $_.ExpectedValue
                actual=ConvertTo-DynomaxNullableString $_.ActualValue
                passed=[bool]$_.Passed
                createdAtUtc=[string]$_.CreatedAtUtc
            }
        })

        $events = @($eventTable.Rows | ForEach-Object {
            [ordered]@{
                eventId=[string]$_.RunEventId
                stepOrder=$(if($_.StepOrder -is [DBNull]){$null}else{[int]$_.StepOrder})
                actionId=ConvertTo-DynomaxNullableString $_.ActionKey
                level=[string]$_.EventLevel
                type=[string]$_.EventType
                message=[string]$_.Message
                data=ConvertFrom-DynomaxDbJson $_.DataJson
                createdAtUtc=[string]$_.CreatedAtUtc
            }
        })

        $cleanup = @($cleanupTable.Rows | ForEach-Object {
            [ordered]@{
                cleanupRegistrationId=[string]$_.CleanupRegistrationId
                cleanupActionId=[string]$_.CleanupActionKey
                objectType=ConvertTo-DynomaxNullableString $_.ObjectType
                objectIdentifier=ConvertTo-DynomaxNullableString $_.ObjectIdentifier
                registration=ConvertFrom-DynomaxDbJson $_.RegistrationJson
                registeredAtUtc=[string]$_.CreatedAtUtc
                cleanupRunId=ConvertTo-DynomaxNullableString $_.CleanupRunId
                status=ConvertTo-DynomaxNullableString $_.Status
                startedAtUtc=ConvertTo-DynomaxNullableString $_.StartedAtUtc
                endedAtUtc=ConvertTo-DynomaxNullableString $_.EndedAtUtc
                message=ConvertTo-DynomaxNullableString $_.Message
            }
        })

        $artifacts = @($artifactTable.Rows | ForEach-Object {
            [ordered]@{
                artifactId=[string]$_.ArtifactId
                actionId=ConvertTo-DynomaxNullableString $_.ActionKey
                type=[string]$_.ArtifactType
                fileName=[string]$_.OriginalFileName
                mimeType=[string]$_.MimeType
                sha256=[string]$_.Sha256
                originalLength=[long]$_.OriginalLength
                storedLength=[long]$_.StoredLength
                compression=[string]$_.CompressionType
                createdAtUtc=[string]$_.CreatedAtUtc
            }
        })

        $summary = [ordered]@{
            schemaVersion=2
            runId=[string]$runRow.RunId
            projectKey=[string]$runRow.ProjectKey
            projectName=[string]$runRow.ProjectName
            workflowKey=ConvertTo-DynomaxNullableString $runRow.WorkflowKey
            workflowName=ConvertTo-DynomaxNullableString $runRow.WorkflowName
            workflowVersionId=$(if($runRow.WorkflowVersionId -is [DBNull]){$null}else{[string]$runRow.WorkflowVersionId})
            workflowVersion=$(if($runRow.WorkflowVersion -is [DBNull]){$null}else{[int]$runRow.WorkflowVersion})
            workflowDefinitionHash=ConvertTo-DynomaxNullableString $runRow.WorkflowDefinitionHash
            environment=[string]$runRow.EnvironmentKey
            status=[string]$runRow.Status
            machine=[string]$runRow.MachineName
            startedAtUtc=[string]$runRow.StartedAtUtc
            endedAtUtc=ConvertTo-DynomaxNullableString $runRow.EndedAtUtc
            packageHash=[string]$runRow.PackageHash
            summary=ConvertTo-DynomaxNullableString $runRow.Summary
            actionCount=$actions.Count
            passedActionCount=@($actions | Where-Object {$_.status -eq 'PASS'}).Count
            cleanupActionCount=@($actions | Where-Object {$_.cleanup}).Count
            artifactCount=$artifacts.Count
        }

        Write-DynomaxJson -Value $summary -Path (Join-Path $OutputDirectory 'RunSummary.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=2;runId=[string]$RunId;actions=$actions}) -Path (Join-Path $OutputDirectory 'ActionResults.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;values=$context}) -Path (Join-Path $OutputDirectory 'ContextSnapshot.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;assertions=$assertions}) -Path (Join-Path $OutputDirectory 'Assertions.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;events=$events}) -Path (Join-Path $OutputDirectory 'Events.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;cleanupRegistrations=$cleanup;cleanupActions=@($actions|Where-Object{$_.cleanup})}) -Path (Join-Path $OutputDirectory 'CleanupSummary.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;artifacts=$artifacts}) -Path (Join-Path $OutputDirectory 'ArtifactManifest.json')

        $lines = @(
            "# Dynomax Run $RunId",'',
            "- Project: $($summary.projectKey) - $($summary.projectName)",
            "- Workflow: $($summary.workflowKey) - $($summary.workflowName)",
            "- Environment: $($summary.environment)",
            "- Status: $($summary.status)",
            "- Machine: $($summary.machine)",
            "- Started UTC: $($summary.startedAtUtc)",
            "- Ended UTC: $($summary.endedAtUtc)",
            "- Actions: $($summary.actionCount)",
            "- SQL artifacts: $($summary.artifactCount)",'',
            '## Actions',''
        )
        foreach ($a in $actions) {
            $suffix = if ($a.cleanup) { ' (cleanup)' } else { '' }
            $lines += "- [$($a.status)] $($a.stepOrder) - $($a.actionId)$suffix"
            if ($a.message) { $lines += "  - $([string]$a.message -replace '`r?`n',' ')" }
        }
        $lines += @('','## Package contents','',
            '- ActionResults.json - complete per-action records and outputs.',
            '- ContextSnapshot.json - all non-secret persisted context.',
            '- Assertions.json - structured assertions recorded for the run.',
            '- Events.json - structured run events.',
            '- CleanupSummary.json - cleanup actions and registrations.',
            '- ArtifactManifest.json - SQL artifact IDs, hashes and sizes.',
            '- WorkflowManifest.json - project/workflow/action source snapshot.',
            '- TestEvidence - Robot reports, logs and screenshots.',
            '- ProjectFindings - project-specific generated reports.',
            '- DynomaxExportManifest.json - file inventory and SHA-256 values.'
        )
        [System.IO.File]::WriteAllLines((Join-Path $OutputDirectory 'RunSummary.md'),$lines,(New-Object System.Text.UTF8Encoding($false)))
        return [pscustomobject]@{Summary=$summary;Actions=$actions;Context=$context;Artifacts=$artifacts;Cleanup=$cleanup}
    }
    finally { $connection.Dispose() }
}

function New-DynomaxStandardZip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceDirectory,
        [Parameter(Mandatory)][string]$DestinationPath
    )
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $source = [System.IO.Path]::GetFullPath($SourceDirectory).TrimEnd('\')
    $destination = [System.IO.Path]::GetFullPath($DestinationPath)
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
    $fileStream = [System.IO.File]::Open($destination,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
    try {
        $archive = New-Object System.IO.Compression.ZipArchive($fileStream,[System.IO.Compression.ZipArchiveMode]::Create,$true)
        try {
            foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse | Sort-Object FullName) {
                $relative = $file.FullName.Substring($source.Length).TrimStart('\').Replace('\','/')
                $entry = $archive.CreateEntry($relative,[System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                $input = [System.IO.File]::OpenRead($file.FullName)
                try { $input.CopyTo($entryStream) } finally { $input.Dispose(); $entryStream.Dispose() }
            }
        }
        finally { $archive.Dispose() }
    }
    finally { $fileStream.Dispose() }

    $verifyStream = [System.IO.File]::OpenRead($destination)
    try {
        $verify = New-Object System.IO.Compression.ZipArchive($verifyStream,[System.IO.Compression.ZipArchiveMode]::Read,$false)
        try {
            if ($verify.Entries.Count -eq 0) { throw 'Result ZIP contains no entries.' }
            foreach ($entry in $verify.Entries) {
                if ($entry.FullName.Contains('\')) { throw "ZIP entry uses a non-standard backslash path: $($entry.FullName)" }
                $stream = $entry.Open(); try { $buffer = New-Object byte[] 8192; while ($stream.Read($buffer,0,$buffer.Length) -gt 0) {} } finally { $stream.Dispose() }
            }
        }
        finally { $verify.Dispose() }
    }
    finally { $verifyStream.Dispose() }
    return $destination
}

function Write-DynomaxExportManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ExportDirectory,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$FrameworkVersion,
        [Parameter(Mandatory)]$TemporaryCleanup
    )
    $root = [System.IO.Path]::GetFullPath($ExportDirectory).TrimEnd('\')
    $files = @()
    foreach ($file in Get-ChildItem -LiteralPath $root -File -Recurse | Where-Object {$_.Name -ne 'DynomaxExportManifest.json'} | Sort-Object FullName) {
        $files += [ordered]@{
            path=$file.FullName.Substring($root.Length).TrimStart('\').Replace('\','/')
            length=[long]$file.Length
            sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
    $manifest = [ordered]@{
        schemaVersion=1
        runId=[string]$RunId
        frameworkVersion=$FrameworkVersion
        generatedAtUtc=[DateTime]::UtcNow.ToString('o')
        completeWorkflowEvidence=$true
        secretValuesExcluded=$true
        zipEntrySeparator='/'
        temporaryWorkspaceCleanup=$TemporaryCleanup
        fileCount=$files.Count
        files=$files
        note='This manifest intentionally excludes its own hash to avoid a recursive self-hash.'
    }
    Write-DynomaxJson -Value $manifest -Path (Join-Path $root 'DynomaxExportManifest.json')
    return $manifest
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

