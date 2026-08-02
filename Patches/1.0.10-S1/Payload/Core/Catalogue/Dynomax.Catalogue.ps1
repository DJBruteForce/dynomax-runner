Set-StrictMode -Version Latest

function Import-DynomaxProjectDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectJsonPath,
        [Parameter(Mandatory)]$SqlConfig
    )

    $definition = Read-DynomaxJson -Path $ProjectJsonPath
    foreach ($required in @('projectKey','displayName','projectType','environments')) {
        if (-not $definition.PSObject.Properties.Name.Contains($required)) { throw "Project definition is missing '$required': $ProjectJsonPath" }
    }
    $canonical = $definition | ConvertTo-Json -Depth 100 -Compress
    $hash = Get-DynomaxTextSha256 -Text $canonical
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $transaction = $connection.BeginTransaction()
        try {
            $projectIdText = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText @'
SELECT CONVERT(nvarchar(36), ProjectId)
FROM dmx.Project
WHERE ProjectKey = @ProjectKey;
'@ -Parameters @{ '@ProjectKey' = [string]$definition.projectKey }

            if (-not $projectIdText) {
                $projectId = [Guid]::NewGuid()
                [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.Project(ProjectId, ProjectKey, DisplayName, ProjectType, IsActive, CreatedAtUtc)
VALUES(@ProjectId, @ProjectKey, @DisplayName, @ProjectType, 1, SYSUTCDATETIME());
'@ -Parameters @{
                    '@ProjectId' = $projectId
                    '@ProjectKey' = [string]$definition.projectKey
                    '@DisplayName' = [string]$definition.displayName
                    '@ProjectType' = [string]$definition.projectType
                })
            }
            else { $projectId = [Guid]$projectIdText }

            $existingVersion = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText @'
SELECT CONVERT(nvarchar(36), ProjectVersionId)
FROM dmx.ProjectVersion
WHERE ProjectId = @ProjectId AND DefinitionHash = @DefinitionHash;
'@ -Parameters @{ '@ProjectId' = $projectId; '@DefinitionHash' = $hash }

            if ($existingVersion) {
                $transaction.Commit()
                return [Guid]$existingVersion
            }

            $versionNumber = [int](Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText @'
SELECT ISNULL(MAX(VersionNumber), 0) + 1 FROM dmx.ProjectVersion WHERE ProjectId = @ProjectId;
'@ -Parameters @{ '@ProjectId' = $projectId })
            $projectVersionId = [Guid]::NewGuid()
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText 'UPDATE dmx.ProjectVersion SET IsCurrent = 0 WHERE ProjectId = @ProjectId;' -Parameters @{ '@ProjectId' = $projectId })
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.ProjectVersion(ProjectVersionId, ProjectId, VersionNumber, DefinitionHash, DefinitionJson, IsCurrent, CreatedAtUtc)
VALUES(@ProjectVersionId, @ProjectId, @VersionNumber, @DefinitionHash, @DefinitionJson, 1, SYSUTCDATETIME());
'@ -Parameters @{
                '@ProjectVersionId' = $projectVersionId
                '@ProjectId' = $projectId
                '@VersionNumber' = $versionNumber
                '@DefinitionHash' = $hash
                '@DefinitionJson' = $canonical
            })

            foreach ($environment in @($definition.environments)) {
                [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.ProjectEnvironment(ProjectEnvironmentId, ProjectVersionId, EnvironmentKey, DisplayName, BaseUrl, DefinitionJson)
VALUES(@Id, @ProjectVersionId, @EnvironmentKey, @DisplayName, @BaseUrl, @DefinitionJson);
'@ -Parameters @{
                    '@Id' = [Guid]::NewGuid()
                    '@ProjectVersionId' = $projectVersionId
                    '@EnvironmentKey' = [string]$environment.key
                    '@DisplayName' = [string]$environment.displayName
                    '@BaseUrl' = [string]$environment.baseUrl
                    '@DefinitionJson' = ($environment | ConvertTo-Json -Depth 50 -Compress)
                })
            }

            $transaction.Commit()
            return $projectVersionId
        }
        catch { try { $transaction.Rollback() } catch { }; throw }
    }
    finally { $connection.Dispose() }
}

function Import-DynomaxActionDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ActionJsonPath,
        [Parameter(Mandatory)]$SqlConfig
    )

    $definition = Read-DynomaxJson -Path $ActionJsonPath
    foreach ($required in @('actionId','displayName','projectKey','engine','entryPoint')) {
        if (-not $definition.PSObject.Properties.Name.Contains($required)) { throw "Action definition is missing '$required': $ActionJsonPath" }
    }
    $actionFolder = Split-Path -Parent $ActionJsonPath
    $entryPoint = Join-Path $actionFolder ([string]$definition.entryPoint)
    if (-not (Test-Path -LiteralPath $entryPoint -PathType Leaf)) { throw "Action entry point does not exist: $entryPoint" }

    $canonical = $definition | ConvertTo-Json -Depth 100 -Compress
    $definitionHash = Get-DynomaxTextSha256 -Text $canonical
    $implementationHash = Get-DynomaxSha256 -Path $entryPoint
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $transaction = $connection.BeginTransaction()
        try {
            $projectIdText = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT CONVERT(nvarchar(36), ProjectId) FROM dmx.Project WHERE ProjectKey = @ProjectKey;' -Parameters @{ '@ProjectKey' = [string]$definition.projectKey }
            if (-not $projectIdText) { throw "Project '$($definition.projectKey)' must be imported before its actions." }
            $projectId = [Guid]$projectIdText

            $actionIdText = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT CONVERT(nvarchar(36), ActionId) FROM dmx.Action WHERE ProjectId = @ProjectId AND ActionKey = @ActionKey;' -Parameters @{ '@ProjectId' = $projectId; '@ActionKey' = [string]$definition.actionId }
            if (-not $actionIdText) {
                $actionId = [Guid]::NewGuid()
                [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.Action(ActionId, ProjectId, ActionKey, DisplayName, IsActive, CreatedAtUtc)
VALUES(@ActionId, @ProjectId, @ActionKey, @DisplayName, 1, SYSUTCDATETIME());
'@ -Parameters @{ '@ActionId' = $actionId; '@ProjectId' = $projectId; '@ActionKey' = [string]$definition.actionId; '@DisplayName' = [string]$definition.displayName })
            }
            else { $actionId = [Guid]$actionIdText }

            $existing = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText @'
SELECT CONVERT(nvarchar(36), ActionVersionId) FROM dmx.ActionVersion
WHERE ActionId = @ActionId AND DefinitionHash = @DefinitionHash AND ImplementationHash = @ImplementationHash;
'@ -Parameters @{ '@ActionId' = $actionId; '@DefinitionHash' = $definitionHash; '@ImplementationHash' = $implementationHash }
            if ($existing) { $transaction.Commit(); return [Guid]$existing }

            $version = [int](Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT ISNULL(MAX(VersionNumber),0)+1 FROM dmx.ActionVersion WHERE ActionId=@ActionId;' -Parameters @{ '@ActionId' = $actionId })
            $actionVersionId = [Guid]::NewGuid()
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText 'UPDATE dmx.ActionVersion SET IsCurrent=0 WHERE ActionId=@ActionId;' -Parameters @{ '@ActionId' = $actionId })
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.ActionVersion
(ActionVersionId, ActionId, VersionNumber, Engine, EntryPoint, KeywordName, SessionBehavior, DefinitionHash, ImplementationHash, DefinitionJson, IsCurrent, CreatedAtUtc)
VALUES
(@Id, @ActionId, @VersionNumber, @Engine, @EntryPoint, @KeywordName, @SessionBehavior, @DefinitionHash, @ImplementationHash, @DefinitionJson, 1, SYSUTCDATETIME());
'@ -Parameters @{
                '@Id' = $actionVersionId
                '@ActionId' = $actionId
                '@VersionNumber' = $version
                '@Engine' = [string]$definition.engine
                '@EntryPoint' = [string]$definition.entryPoint
                '@KeywordName' = $(if (Get-DynomaxPropertyValue -Object $definition -Name 'keyword') { [string](Get-DynomaxPropertyValue -Object $definition -Name 'keyword') } else { [DBNull]::Value })
                '@SessionBehavior' = [string](Get-DynomaxPropertyValue -Object $definition -Name 'sessionBehavior' -DefaultValue 'DoesNotUseBrowser')
                '@DefinitionHash' = $definitionHash
                '@ImplementationHash' = $implementationHash
                '@DefinitionJson' = $canonical
            })
            $transaction.Commit()
            return $actionVersionId
        }
        catch { try { $transaction.Rollback() } catch { }; throw }
    }
    finally { $connection.Dispose() }
}

function Import-DynomaxWorkflowDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$WorkflowJsonPath,
        [Parameter(Mandatory)]$SqlConfig
    )
    $definition = Read-DynomaxJson -Path $WorkflowJsonPath
    foreach ($required in @('workflowId','displayName','projectKey','environment','steps')) {
        if (-not $definition.PSObject.Properties.Name.Contains($required)) { throw "Workflow definition is missing '$required': $WorkflowJsonPath" }
    }
    $canonical = $definition | ConvertTo-Json -Depth 100 -Compress
    $hash = Get-DynomaxTextSha256 -Text $canonical
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $transaction = $connection.BeginTransaction()
        try {
            $projectIdText = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT CONVERT(nvarchar(36), ProjectId) FROM dmx.Project WHERE ProjectKey=@ProjectKey;' -Parameters @{ '@ProjectKey' = [string]$definition.projectKey }
            if (-not $projectIdText) { throw "Project '$($definition.projectKey)' must be imported before workflows." }
            $projectId = [Guid]$projectIdText

            $workflowIdText = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT CONVERT(nvarchar(36), WorkflowId) FROM dmx.Workflow WHERE ProjectId=@ProjectId AND WorkflowKey=@WorkflowKey;' -Parameters @{ '@ProjectId'=$projectId; '@WorkflowKey'=[string]$definition.workflowId }
            if (-not $workflowIdText) {
                $workflowId = [Guid]::NewGuid()
                [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.Workflow(WorkflowId,ProjectId,WorkflowKey,DisplayName,IsActive,CreatedAtUtc)
VALUES(@Id,@ProjectId,@WorkflowKey,@DisplayName,1,SYSUTCDATETIME());
'@ -Parameters @{ '@Id'=$workflowId; '@ProjectId'=$projectId; '@WorkflowKey'=[string]$definition.workflowId; '@DisplayName'=[string]$definition.displayName })
            }
            else { $workflowId = [Guid]$workflowIdText }

            $existing = Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT CONVERT(nvarchar(36),WorkflowVersionId) FROM dmx.WorkflowVersion WHERE WorkflowId=@WorkflowId AND DefinitionHash=@Hash;' -Parameters @{ '@WorkflowId'=$workflowId; '@Hash'=$hash }
            if ($existing) { $transaction.Commit(); return [Guid]$existing }

            $version = [int](Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT ISNULL(MAX(VersionNumber),0)+1 FROM dmx.WorkflowVersion WHERE WorkflowId=@WorkflowId;' -Parameters @{ '@WorkflowId'=$workflowId })
            $workflowVersionId = [Guid]::NewGuid()
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText 'UPDATE dmx.WorkflowVersion SET IsCurrent=0 WHERE WorkflowId=@WorkflowId;' -Parameters @{ '@WorkflowId'=$workflowId })
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.WorkflowVersion(WorkflowVersionId,WorkflowId,VersionNumber,EnvironmentKey,DefinitionHash,DefinitionJson,IsCurrent,CreatedAtUtc)
VALUES(@Id,@WorkflowId,@VersionNumber,@EnvironmentKey,@Hash,@Json,1,SYSUTCDATETIME());
'@ -Parameters @{ '@Id'=$workflowVersionId; '@WorkflowId'=$workflowId; '@VersionNumber'=$version; '@EnvironmentKey'=[string]$definition.environment; '@Hash'=$hash; '@Json'=$canonical })

            foreach ($step in @($definition.steps | Sort-Object order)) {
                [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
INSERT INTO dmx.WorkflowStep(WorkflowStepId,WorkflowVersionId,StepOrder,ActionKey,RequestedActionVersion,IsCleanup,ContinueOnFailure,DefinitionJson)
VALUES(@Id,@WorkflowVersionId,@StepOrder,@ActionKey,@RequestedActionVersion,@IsCleanup,@ContinueOnFailure,@DefinitionJson);
'@ -Parameters @{
                    '@Id'=[Guid]::NewGuid(); '@WorkflowVersionId'=$workflowVersionId; '@StepOrder'=[int]$step.order; '@ActionKey'=[string]$step.actionId
                    '@RequestedActionVersion'=$(if (Get-DynomaxPropertyValue -Object $step -Name 'actionVersion') {[int](Get-DynomaxPropertyValue -Object $step -Name 'actionVersion')} else {[DBNull]::Value})
                    '@IsCleanup'=[bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)
                    '@ContinueOnFailure'=[bool](Get-DynomaxPropertyValue -Object $step -Name 'continueOnFailure' -DefaultValue $false)
                    '@DefinitionJson'=($step | ConvertTo-Json -Depth 50 -Compress)
                })
            }
            $transaction.Commit()
            return $workflowVersionId
        }
        catch { try { $transaction.Rollback() } catch { }; throw }
    }
    finally { $connection.Dispose() }
}

function Get-DynomaxActionVersionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SqlConfig,
        [Parameter(Mandatory)][string]$ProjectKey,
        [Parameter(Mandatory)][string]$ActionKey,
        [object]$RequestedActionVersion = $null
    )

    $hasRequestedVersion = $null -ne $RequestedActionVersion -and
        -not ($RequestedActionVersion -is [DBNull]) -and
        -not [string]::IsNullOrWhiteSpace([string]$RequestedActionVersion)

    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        if ($hasRequestedVersion) {
            $table = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT av.ActionVersionId,av.VersionNumber,av.Engine,av.EntryPoint,av.KeywordName,av.SessionBehavior,
       av.DefinitionHash,av.ImplementationHash,av.DefinitionJson,av.IsCurrent
FROM dmx.Project p
JOIN dmx.Action a ON a.ProjectId=p.ProjectId AND a.ActionKey=@ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.VersionNumber=@VersionNumber
WHERE p.ProjectKey=@ProjectKey;
'@ -Parameters @{
                '@ProjectKey' = $ProjectKey
                '@ActionKey' = $ActionKey
                '@VersionNumber' = [int]$RequestedActionVersion
            }
        }
        else {
            $table = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT av.ActionVersionId,av.VersionNumber,av.Engine,av.EntryPoint,av.KeywordName,av.SessionBehavior,
       av.DefinitionHash,av.ImplementationHash,av.DefinitionJson,av.IsCurrent
FROM dmx.Project p
JOIN dmx.Action a ON a.ProjectId=p.ProjectId AND a.ActionKey=@ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.IsCurrent=1
WHERE p.ProjectKey=@ProjectKey;
'@ -Parameters @{
                '@ProjectKey' = $ProjectKey
                '@ActionKey' = $ActionKey
            }
        }

        if ($table.Rows.Count -eq 0) { return $null }
        if ($table.Rows.Count -ne 1) {
            $versionText = if ($hasRequestedVersion) { [string]$RequestedActionVersion } else { 'current' }
            throw "Expected one $versionText catalogue version for action '$ActionKey' in project '$ProjectKey', found $($table.Rows.Count)."
        }

        $row = $table.Rows[0]
        return [pscustomobject]@{
            ActionVersionId = [Guid]$row.ActionVersionId
            VersionNumber = [int]$row.VersionNumber
            Engine = [string]$row.Engine
            EntryPoint = [string]$row.EntryPoint
            KeywordName = $(if ($row.KeywordName -is [DBNull]) { $null } else { [string]$row.KeywordName })
            SessionBehavior = [string]$row.SessionBehavior
            DefinitionHash = [string]$row.DefinitionHash
            ImplementationHash = [string]$row.ImplementationHash
            DefinitionJson = [string]$row.DefinitionJson
            IsCurrent = [bool]$row.IsCurrent
        }
    }
    finally { $connection.Dispose() }
}

function Get-DynomaxWorkflowVersionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SqlConfig,
        [Parameter(Mandatory)][Guid]$WorkflowVersionId,
        [Parameter(Mandatory)][string]$ProjectKey,
        [Parameter(Mandatory)][string]$WorkflowKey
    )

    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $table = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT wv.WorkflowVersionId,wv.VersionNumber,wv.EnvironmentKey,wv.DefinitionHash,wv.DefinitionJson,wv.IsCurrent
FROM dmx.Project p
JOIN dmx.Workflow w ON w.ProjectId=p.ProjectId AND w.WorkflowKey=@WorkflowKey
JOIN dmx.WorkflowVersion wv ON wv.WorkflowId=w.WorkflowId AND wv.WorkflowVersionId=@WorkflowVersionId
WHERE p.ProjectKey=@ProjectKey;
'@ -Parameters @{
            '@ProjectKey' = $ProjectKey
            '@WorkflowKey' = $WorkflowKey
            '@WorkflowVersionId' = $WorkflowVersionId
        }

        if ($table.Rows.Count -ne 1) {
            throw "Workflow version '$WorkflowVersionId' does not belong to '$ProjectKey/$WorkflowKey'."
        }

        $row = $table.Rows[0]
        return [pscustomobject]@{
            WorkflowVersionId = [Guid]$row.WorkflowVersionId
            VersionNumber = [int]$row.VersionNumber
            EnvironmentKey = [string]$row.EnvironmentKey
            DefinitionHash = [string]$row.DefinitionHash
            DefinitionJson = [string]$row.DefinitionJson
            IsCurrent = [bool]$row.IsCurrent
        }
    }
    finally { $connection.Dispose() }
}

function Import-DynomaxProjectFolder {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ProjectFolder, [Parameter(Mandatory)]$SqlConfig)
    $projectJson = Join-Path $ProjectFolder 'Project-And-Config\project.json'
    [void](Import-DynomaxProjectDefinition -ProjectJsonPath $projectJson -SqlConfig $SqlConfig)
    $library = Join-Path $ProjectFolder 'Project-Library'
    if (Test-Path -LiteralPath $library) {
        Get-ChildItem -LiteralPath $library -Filter action.json -File -Recurse | Sort-Object FullName | ForEach-Object {
            [void](Import-DynomaxActionDefinition -ActionJsonPath $_.FullName -SqlConfig $SqlConfig)
        }
    }
    $sessions = Join-Path $ProjectFolder 'Project-Workflow\Sessions'
    if (Test-Path -LiteralPath $sessions) {
        Get-ChildItem -LiteralPath $sessions -Filter workflow.json -File -Recurse | Sort-Object FullName | ForEach-Object {
            [void](Import-DynomaxWorkflowDefinition -WorkflowJsonPath $_.FullName -SqlConfig $SqlConfig)
        }
    }
}
