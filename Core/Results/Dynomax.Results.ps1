Set-StrictMode -Version Latest

function Get-DynomaxRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$TargetPath
    )
    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd([char[]]@('\','/'))
    $target = [System.IO.Path]::GetFullPath($TargetPath)
    if($target.Equals($base,[System.StringComparison]::OrdinalIgnoreCase)){return ''}
    $prefix = $base + [System.IO.Path]::DirectorySeparatorChar
    if(-not $target.StartsWith($prefix,[System.StringComparison]::OrdinalIgnoreCase)){
        throw ("Path '{0}' is outside base path '{1}'." -f $target,$base)
    }
    return $target.Substring($prefix.Length)
}

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
        [switch]$AllowUnresolvedActionVersion,
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    $ownsConnection = $null -eq $Connection
    $activeConnection = $Connection
    if($ownsConnection){$activeConnection = Open-DynomaxConnection -SqlConfig $SqlConfig}
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
            $inserted=Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,@StepOrder,av.ActionVersionId,@ActionKey,@Status,@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,@OutputJson
FROM dmx.TestRun tr
JOIN dmx.Action a ON a.ProjectId=tr.ProjectId AND a.ActionKey=@ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.ActionVersionId=@ActionVersionId
WHERE tr.RunId=@RunId;
'@ -Parameters $parameters
        }
        elseif ($AllowUnresolvedActionVersion) {
            $inserted=Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,@StepOrder,NULL,@ActionKey,@Status,@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,@OutputJson
FROM dmx.TestRun tr
WHERE tr.RunId=@RunId;
'@ -Parameters $parameters
        }
        else {
            $inserted=Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
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
    finally { if($ownsConnection -and $activeConnection){$activeConnection.Dispose()} }
}

function Add-DynomaxMissingControlFlowActionRuns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][object[]]$Steps,
        [string]$ContextPath,
        [string]$Message = 'Physical execution slot was not selected before Workflow control flow terminated.',
        [bool]$IsCleanup = $false
    )
    if($Steps.Count -eq 0){return 0}
    $connection=Open-DynomaxConnection -SqlConfig $SqlConfig
    try{
        $existingRows=Invoke-DynomaxSqlRows -Connection $connection -CommandText 'SELECT StepOrder FROM dmx.ActionRun WHERE RunId=@RunId;' -Parameters @{ '@RunId'=$RunId }
        $existing=[System.Collections.Generic.HashSet[int]]::new()
        foreach($row in @($existingRows)){[void]$existing.Add([int]$row.StepOrder)}
        $reusedStepIds=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        if($ContextPath -and (Test-Path -LiteralPath $ContextPath -PathType Leaf)){
            $context=Read-DynomaxJson -Path $ContextPath
            $continuation=Get-DynomaxPropertyValue -Object $context -Name 'continuation' -DefaultValue $null
            $plan=if($null -ne $continuation){Get-DynomaxPropertyValue -Object $continuation -Name 'plan' -DefaultValue $null}else{$null}
            $planItems=if($null -ne $plan){@(Get-DynomaxPropertyValue -Object $plan -Name 'items' -DefaultValue @())}else{@()}
            foreach($item in @($planItems)){
                if(([string](Get-DynomaxPropertyValue -Object $item -Name 'decision' -DefaultValue '')).ToUpperInvariant() -eq 'REUSE'){
                    [void]$reusedStepIds.Add([string](Get-DynomaxPropertyValue -Object $item -Name 'targetStepId' -DefaultValue ''))
                }
            }
        }

        $pending=[System.Collections.Generic.List[object]]::new()
        foreach($step in @($Steps|Sort-Object order)){
            $stepId=[string](Get-DynomaxPropertyValue -Object $step -Name 'stepId' -DefaultValue '')
            if($reusedStepIds.Contains($stepId)){continue}
            $stepOrder=[int](Get-DynomaxPropertyValue -Object $step -Name 'order' -DefaultValue 0)
            if($existing.Contains($stepOrder)){continue}
            $actionKey=[string](Get-DynomaxPropertyValue -Object $step -Name 'actionId' -DefaultValue '')
            $versionText=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue '')
            $actionVersionId=[Guid]::Empty
            if([string]::IsNullOrWhiteSpace($actionKey) -or -not [Guid]::TryParse($versionText,[ref]$actionVersionId)){
                throw "Cannot finalize skipped physical slot '$stepOrder' because its exact Action identity is incomplete."
            }
            $pending.Add([pscustomobject]@{StepOrder=$stepOrder;ActionKey=$actionKey;ActionVersionId=$actionVersionId})
        }
        if($pending.Count -eq 0){return 0}

        # Persist bookkeeping-only physical slots in bounded batches. A large bounded control-flow
        # schedule can contain hundreds or thousands of slots; one SQL round-trip per skipped slot
        # makes Main->Cleanup and StopCleanup transitions scale with the unselected schedule size.
        $insertedCount=0
        $batchSize=200
        for($offset=0;$offset -lt $pending.Count;$offset+=$batchSize){
            $count=[Math]::Min($batchSize,$pending.Count-$offset)
            $selects=New-Object System.Collections.Generic.List[string]
            $parameters=@{ '@RunId'=$RunId; '@Message'=$Message; '@IsCleanup'=$IsCleanup }
            for($i=0;$i -lt $count;$i++){
                $item=$pending[$offset+$i]
                $selects.Add("SELECT @StepOrder$i AS StepOrder,@ActionKey$i AS ActionKey,@ActionVersionId$i AS ActionVersionId")
                $parameters["@StepOrder$i"]=[int]$item.StepOrder
                $parameters["@ActionKey$i"]=[string]$item.ActionKey
                $parameters["@ActionVersionId$i"]=[Guid]$item.ActionVersionId
            }
            $desiredSql=[string]::Join("`nUNION ALL`n",$selects)
            $command=@"
WITH desired AS (
$desiredSql
)
INSERT INTO dmx.ActionRun(ActionRunId,RunId,StepOrder,ActionVersionId,ActionKey,Status,IsCleanup,StartedAtUtc,EndedAtUtc,Message,OutputJson)
SELECT NEWID(),@RunId,d.StepOrder,av.ActionVersionId,d.ActionKey,N'SKIPPED',@IsCleanup,SYSUTCDATETIME(),SYSUTCDATETIME(),@Message,NULL
FROM desired d
JOIN dmx.TestRun tr ON tr.RunId=@RunId
JOIN dmx.Action a ON a.ProjectId=tr.ProjectId AND a.ActionKey=d.ActionKey
JOIN dmx.ActionVersion av ON av.ActionId=a.ActionId AND av.ActionVersionId=d.ActionVersionId
WHERE NOT EXISTS(SELECT 1 FROM dmx.ActionRun ar WHERE ar.RunId=@RunId AND ar.StepOrder=d.StepOrder);
"@
            $inserted=[int](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText $command -Parameters $parameters)
            $insertedCount += $inserted
        }
        return $insertedCount
    }
    finally{$connection.Dispose()}
}

function Set-DynomaxContextObjectProperty {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string]$Name,$Value)
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property){$Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value}else{$property.Value=$Value}
}

function Set-DynomaxRunDataPoolStepOutputs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$StepId,
        [Parameter(Mandatory)][string]$WorkflowNodeId,
        [Parameter(Mandatory)][int]$ExecutionSlot,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][object[]]$OutputDefinitions,
        $OutputObject
    )
    $pool=Get-DynomaxPropertyValue -Object $Context -Name 'runDataPool' -DefaultValue $null
    if($null -eq $pool){$pool=[pscustomobject][ordered]@{schemaVersion=1;steps=[pscustomobject][ordered]@{}};Set-DynomaxContextObjectProperty -Object $Context -Name 'runDataPool' -Value $pool}
    $steps=Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null
    if($null -eq $steps){$steps=[pscustomobject][ordered]@{};Set-DynomaxContextObjectProperty -Object $pool -Name 'steps' -Value $steps}
    $outputs=[pscustomobject][ordered]@{}
    foreach($definition in @($OutputDefinitions)){
        $name=[string](Get-DynomaxPropertyValue -Object $definition -Name 'name' -DefaultValue '')
        if([string]::IsNullOrWhiteSpace($name)){continue}
        $classification=[string](Get-DynomaxPropertyValue -Object $definition -Name 'classification' -DefaultValue 'Normal')
        $persist=[bool](Get-DynomaxPropertyValue -Object $definition -Name 'persistInResult' -DefaultValue $true)
        $available=$false;$value=$null
        if($null -ne $OutputObject){$prop=$OutputObject.PSObject.Properties[$name];if($null -ne $prop){$available=$true;$value=$prop.Value}}
        if(-not $available){$prop=$Context.values.PSObject.Properties[$name];if($null -ne $prop){$available=$true;$value=$prop.Value}}
        Set-DynomaxContextObjectProperty -Object $outputs -Name $name -Value ([pscustomobject][ordered]@{available=$available;value=$value;classification=$classification;persistInResult=$persist})
        if($available){Set-DynomaxContextObjectProperty -Object $Context.values -Name $name -Value $value}
    }
    $step=[pscustomobject][ordered]@{stepId=$StepId;workflowNodeId=$WorkflowNodeId;executionSlot=$ExecutionSlot;actionKey=$ActionKey;capturedAtUtc=[DateTime]::UtcNow.ToString('o');outputs=$outputs}
    Set-DynomaxContextObjectProperty -Object $steps -Name $StepId -Value $step
    return $step
}

function ConvertTo-DynomaxSafeRunDataPoolStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Step,
        [Parameter(Mandatory)][string]$FallbackStepId
    )
    $safeOutputs=[pscustomobject][ordered]@{}
    $outputs=Get-DynomaxPropertyValue -Object $Step -Name 'outputs' -DefaultValue $null
    if($null -ne $outputs){foreach($outputProperty in @($outputs.PSObject.Properties)){
        $output=$outputProperty.Value
        $available=[bool](Get-DynomaxPropertyValue -Object $output -Name 'available' -DefaultValue $false)
        $classification=[string](Get-DynomaxPropertyValue -Object $output -Name 'classification' -DefaultValue 'Normal')
        $persist=[bool](Get-DynomaxPropertyValue -Object $output -Name 'persistInResult' -DefaultValue $true)
        $canExpose=$available -and $classification -eq 'Normal' -and $persist
        Set-DynomaxContextObjectProperty -Object $safeOutputs -Name ([string]$outputProperty.Name) -Value ([pscustomobject][ordered]@{
            available=$available
            value=$(if($canExpose){Get-DynomaxPropertyValue -Object $output -Name 'value' -DefaultValue $null}else{$null})
            classification=$classification
            persistInResult=$persist
            redacted=(-not $canExpose -and $available)
        })
    }}
    return [pscustomobject][ordered]@{
        stepId=[string](Get-DynomaxPropertyValue -Object $Step -Name 'stepId' -DefaultValue $FallbackStepId)
        workflowNodeId=[string](Get-DynomaxPropertyValue -Object $Step -Name 'workflowNodeId' -DefaultValue '')
        executionSlot=[int](Get-DynomaxPropertyValue -Object $Step -Name 'executionSlot' -DefaultValue 1)
        actionKey=[string](Get-DynomaxPropertyValue -Object $Step -Name 'actionKey' -DefaultValue '')
        capturedAtUtc=[string](Get-DynomaxPropertyValue -Object $Step -Name 'capturedAtUtc' -DefaultValue '')
        outputs=$safeOutputs
    }
}

function ConvertTo-DynomaxSafeRunDataPool {
    [CmdletBinding()]
    param($RunDataPool)
    $safeSteps=[pscustomobject][ordered]@{}
    if($null -ne $RunDataPool){
        $steps=Get-DynomaxPropertyValue -Object $RunDataPool -Name 'steps' -DefaultValue $null
        if($null -ne $steps){foreach($stepProperty in @($steps.PSObject.Properties)){
            Set-DynomaxContextObjectProperty -Object $safeSteps -Name ([string]$stepProperty.Name) -Value (ConvertTo-DynomaxSafeRunDataPoolStep -Step $stepProperty.Value -FallbackStepId ([string]$stepProperty.Name))
        }}
    }
    return [pscustomobject][ordered]@{schemaVersion=1;steps=$safeSteps}
}

function Set-DynomaxRunDataPoolStepInSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$StepId,
        [Parameter(Mandatory)]$Step,
        [System.Data.SqlClient.SqlConnection]$Connection,
        [hashtable]$PersistedContextCache
    )
    $safeStep=ConvertTo-DynomaxSafeRunDataPoolStep -Step $Step -FallbackStepId $StepId
    $valueJson=([ordered]@{value=$safeStep}|ConvertTo-Json -Depth 100 -Compress)
    $stepBytes=[System.Text.Encoding]::UTF8.GetBytes($StepId)
    $sha=[System.Security.Cryptography.SHA256]::Create()
    try{$stepHash=([System.BitConverter]::ToString($sha.ComputeHash($stepBytes))).Replace('-','').ToLowerInvariant()}
    finally{$sha.Dispose()}
    # The hash keeps ContextKey bounded and safe while the payload retains the exact immutable StepId.
    $contextKey='__dynomax.runDataPool.step.'+$stepHash
    $cacheValue=('0|{0}' -f $valueJson)
    if($null -ne $PersistedContextCache -and $PersistedContextCache.ContainsKey($contextKey) -and [string]$PersistedContextCache[$contextKey] -ceq $cacheValue){return}

    $ownsConnection=$null -eq $Connection
    $activeConnection=$Connection
    if($ownsConnection){$activeConnection=Open-DynomaxConnection -SqlConfig $SqlConfig}
    try{
        [void](Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
MERGE dmx.RunContextValue AS target
USING (SELECT @RunId AS RunId,@ContextKey AS ContextKey) AS source
ON target.RunId=source.RunId AND target.ContextKey=source.ContextKey
WHEN MATCHED THEN UPDATE SET ValueJson=@ValueJson,IsSecret=0,UpdatedAtUtc=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(RunContextValueId,RunId,ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc)
VALUES(NEWID(),@RunId,@ContextKey,@ValueJson,0,SYSUTCDATETIME(),SYSUTCDATETIME());
'@ -Parameters @{ '@RunId'=$RunId; '@ContextKey'=$contextKey; '@ValueJson'=$valueJson })
        if($null -ne $PersistedContextCache){$PersistedContextCache[$contextKey]=$cacheValue}
    }
    finally{if($ownsConnection -and $activeConnection){$activeConnection.Dispose()}}
}

function Set-DynomaxContextStepInSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$StepId,
        [System.Data.SqlClient.SqlConnection]$Connection,
        [hashtable]$PersistedContextCache
    )
    $ownsConnection=$null -eq $Connection
    $activeConnection=$Connection
    if($ownsConnection){$activeConnection=Open-DynomaxConnection -SqlConfig $SqlConfig}
    try{
        $pool=Get-DynomaxPropertyValue -Object $Context -Name 'runDataPool' -DefaultValue $null
        $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
        $stepProperty=if($null -ne $steps){$steps.PSObject.Properties[$StepId]}else{$null}
        if($null -ne $stepProperty -and $null -ne $PersistedContextCache){
            $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
            if($null -ne $outputs){foreach($outputProperty in @($outputs.PSObject.Properties)){
                $classification=[string](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'classification' -DefaultValue 'Normal')
                $persist=[bool](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'persistInResult' -DefaultValue $true)
                if($classification -ne 'Normal' -or -not $persist){
                    $PersistedContextCache['__dynomax.sensitiveOutputName.'+[string]$outputProperty.Name]=$true
                }
            }}
        }
        Set-DynomaxContextValuesInSql -SqlConfig $SqlConfig -RunId $RunId -Context $Context -Connection $activeConnection -PersistedContextCache $PersistedContextCache -PersistRunDataPool:$false -InspectRunDataPool:$false
        if($null -ne $stepProperty){Set-DynomaxRunDataPoolStepInSql -SqlConfig $SqlConfig -RunId $RunId -StepId $StepId -Step $stepProperty.Value -Connection $activeConnection -PersistedContextCache $PersistedContextCache}
    }
    finally{if($ownsConnection -and $activeConnection){$activeConnection.Dispose()}}
}

function Set-DynomaxContextValuesIndividuallyInSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)]$PendingValues
    )
    foreach($pending in @($PendingValues)){
        [void](Invoke-DynomaxSqlNonQuery -Connection $Connection -CommandText @'
MERGE dmx.RunContextValue AS target
USING (SELECT @RunId AS RunId,@ContextKey AS ContextKey) AS source
ON target.RunId=source.RunId AND target.ContextKey=source.ContextKey
WHEN MATCHED THEN UPDATE SET ValueJson=@ValueJson,IsSecret=@IsSecret,UpdatedAtUtc=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(RunContextValueId,RunId,ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc)
VALUES(NEWID(),@RunId,@ContextKey,@ValueJson,@IsSecret,SYSUTCDATETIME(),SYSUTCDATETIME());
'@ -Parameters @{
            '@RunId'=$RunId
            '@ContextKey'=[string]$pending.contextKey
            '@ValueJson'=[string]$pending.valueJson
            '@IsSecret'=[bool]$pending.isSecret
        })
    }
}

function Set-DynomaxContextValuesInSql {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)]$Context,
        [System.Data.SqlClient.SqlConnection]$Connection,
        [hashtable]$PersistedContextCache,
        [bool]$PersistRunDataPool=$true,
        [bool]$InspectRunDataPool=$true
    )
    $ownsConnection = $null -eq $Connection
    $activeConnection = $Connection
    if($ownsConnection){$activeConnection = Open-DynomaxConnection -SqlConfig $SqlConfig}
    try {
        $secretLookup=@{}
        foreach($secretKey in @(Get-DynomaxPropertyValue -Object $Context -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$secretKey)){$secretLookup[[string]$secretKey]=$true}}
        $sensitiveOutputNames=@{}
        if($null -ne $PersistedContextCache){
            foreach($cacheKey in @($PersistedContextCache.Keys)){
                $prefix='__dynomax.sensitiveOutputName.'
                if(([string]$cacheKey).StartsWith($prefix,[System.StringComparison]::Ordinal)){
                    $sensitiveOutputNames[([string]$cacheKey).Substring($prefix.Length)]=$true
                }
            }
        }
        $pool=Get-DynomaxPropertyValue -Object $Context -Name 'runDataPool' -DefaultValue $null
        if($InspectRunDataPool -and $null -ne $pool){
            $steps=Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null
            if($null -ne $steps){foreach($stepProperty in @($steps.PSObject.Properties)){
                $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
                if($null -ne $outputs){foreach($outputProperty in @($outputs.PSObject.Properties)){
                    $classification=[string](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'classification' -DefaultValue 'Normal')
                    $persist=[bool](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'persistInResult' -DefaultValue $true)
                    if($classification -ne 'Normal' -or -not $persist){
                        $name=[string]$outputProperty.Name
                        $sensitiveOutputNames[$name]=$true
                        if($null -ne $PersistedContextCache){$PersistedContextCache['__dynomax.sensitiveOutputName.'+$name]=$true}
                    }
                }}
            }}
        }
        $pendingValues=[System.Collections.Generic.List[object]]::new()
        foreach ($property in $Context.values.PSObject.Properties) {
            $contextKey=[string]$property.Name
            $isSecret=$secretLookup.ContainsKey($contextKey)
            $redact=$isSecret -or $sensitiveOutputNames.ContainsKey($contextKey)
            $valueJson=$(if($redact){'{"redacted":true}'}else{([ordered]@{ value = $property.Value }) | ConvertTo-Json -Depth 50 -Compress})
            $cacheValue=('{0}|{1}' -f $(if($isSecret){'1'}else{'0'}),$valueJson)
            if($null -ne $PersistedContextCache -and $PersistedContextCache.ContainsKey($contextKey) -and [string]$PersistedContextCache[$contextKey] -ceq $cacheValue){continue}
            $pendingValues.Add([ordered]@{
                contextKey=$contextKey
                valueJson=$valueJson
                isSecret=[bool]$isSecret
                cacheValue=$cacheValue
            })
        }
        if($pendingValues.Count -gt 0){
            $batchDisabled=$null -ne $PersistedContextCache -and $PersistedContextCache.ContainsKey('__dynomax.contextBatchDisabled')
            if($batchDisabled){
                Set-DynomaxContextValuesIndividuallyInSql -Connection $activeConnection -RunId $RunId -PendingValues $pendingValues
            }
            else{
                try{
                    $payload=@($pendingValues | ForEach-Object { [ordered]@{contextKey=$_.contextKey;valueJson=$_.valueJson;isSecret=$_.isSecret} })
                    $valuesJson=ConvertTo-Json -InputObject ([object[]]$payload) -Depth 20 -Compress
                    [void](Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Source TABLE
    (
        ContextKey nvarchar(450) NOT NULL PRIMARY KEY,
        ValueJson nvarchar(max) NULL,
        IsSecret bit NOT NULL
    );
    INSERT INTO @Source(ContextKey,ValueJson,IsSecret)
    SELECT ContextKey,ValueJson,IsSecret
    FROM OPENJSON(@ValuesJson)
    WITH
    (
        ContextKey nvarchar(450) '$.contextKey',
        ValueJson nvarchar(max) '$.valueJson',
        IsSecret bit '$.isSecret'
    )
    WHERE ContextKey IS NOT NULL;

    UPDATE target
    SET target.ValueJson=source.ValueJson,
        target.IsSecret=source.IsSecret,
        target.UpdatedAtUtc=SYSUTCDATETIME()
    FROM dmx.RunContextValue target
    JOIN @Source source ON source.ContextKey=target.ContextKey
    WHERE target.RunId=@RunId;

    INSERT INTO dmx.RunContextValue
    (
        RunContextValueId,RunId,ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc
    )
    SELECT NEWID(),@RunId,source.ContextKey,source.ValueJson,source.IsSecret,SYSUTCDATETIME(),SYSUTCDATETIME()
    FROM @Source source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dmx.RunContextValue existing
        WHERE existing.RunId=@RunId AND existing.ContextKey=source.ContextKey
    );
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
'@ -Parameters @{ '@RunId'=$RunId; '@ValuesJson'=$valuesJson })
                }
                catch{
                    $safeBatchMessage=([string]$_.Exception.Message -replace '[\r\n\t]+',' ').Trim()
                    if($safeBatchMessage.Length -gt 1500){$safeBatchMessage=$safeBatchMessage.Substring(0,1500)}
                    Write-Warning ("Batched RunContext persistence failed; using deterministic per-key fallback for the remainder of this Run. {0}" -f $safeBatchMessage)
                    if($null -ne $PersistedContextCache){$PersistedContextCache['__dynomax.contextBatchDisabled']=$safeBatchMessage}
                    Set-DynomaxContextValuesIndividuallyInSql -Connection $activeConnection -RunId $RunId -PendingValues $pendingValues
                    try{
                        Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Warning' -EventType 'Runtime.ContextBatchFallback' -Message 'Batched RunContext persistence failed and Dynomax switched to the deterministic per-key fallback for this Run.' -Data ([ordered]@{error=$safeBatchMessage;pendingValueCount=$pendingValues.Count}) -Connection $activeConnection
                    }catch{Write-Warning ("Could not persist the context-batch fallback diagnostic event: {0}" -f $_.Exception.Message)}
                }
            }
            if($null -ne $PersistedContextCache){
                foreach($pending in $pendingValues.ToArray()){$PersistedContextCache[[string]$pending.contextKey]=[string]$pending.cacheValue}
            }
        }
        if($PersistRunDataPool){
            $safePool=ConvertTo-DynomaxSafeRunDataPool -RunDataPool $pool
            $poolJson=([ordered]@{value=$safePool}|ConvertTo-Json -Depth 100 -Compress)
            $poolCacheKey='__dynomax.runDataPool'
            $poolCacheValue=('0|{0}' -f $poolJson)
            if($null -eq $PersistedContextCache -or -not $PersistedContextCache.ContainsKey($poolCacheKey) -or [string]$PersistedContextCache[$poolCacheKey] -cne $poolCacheValue){
                [void](Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    MERGE dmx.RunContextValue AS target
    USING (SELECT @RunId AS RunId,N'__dynomax.runDataPool' AS ContextKey) AS source
    ON target.RunId=source.RunId AND target.ContextKey=source.ContextKey
    WHEN MATCHED THEN UPDATE SET ValueJson=@ValueJson,IsSecret=0,UpdatedAtUtc=SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT(RunContextValueId,RunId,ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc)
    VALUES(NEWID(),@RunId,N'__dynomax.runDataPool',@ValueJson,0,SYSUTCDATETIME(),SYSUTCDATETIME());
    DELETE FROM dmx.RunContextValue
    WHERE RunId=@RunId AND ContextKey LIKE N'__dynomax.runDataPool.step.%';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
'@ -Parameters @{ '@RunId'=$RunId; '@ValueJson'=$poolJson })
                if($null -ne $PersistedContextCache){
                    $PersistedContextCache[$poolCacheKey]=$poolCacheValue
                    foreach($cachedKey in @($PersistedContextCache.Keys)){
                        if(([string]$cachedKey).StartsWith('__dynomax.runDataPool.step.',[System.StringComparison]::Ordinal)){$PersistedContextCache.Remove($cachedKey)}
                    }
                }
            }
        }
    }
    finally { if($ownsConnection -and $activeConnection){$activeConnection.Dispose()} }
}

function Add-DynomaxArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [string]$ActionKey,
        [Parameter(Mandatory)][string]$ArtifactType,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][long]$MaximumBytes,
        [System.Data.SqlClient.SqlConnection]$Connection,
        [hashtable]$ContentIdCache
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt $MaximumBytes) { return $null }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()

    $ownsConnection = $null -eq $Connection
    $activeConnection = $Connection
    try {
        if ($ownsConnection) { $activeConnection = Open-DynomaxConnection -SqlConfig $SqlConfig }
        $contentId = [Guid]::Empty
        if ($null -ne $ContentIdCache -and $ContentIdCache.ContainsKey($hash)) {
            $contentId = [Guid]$ContentIdCache[$hash]
        }
        else {
            $contentIdText = Invoke-DynomaxSqlScalar -Connection $activeConnection -CommandText 'SELECT CONVERT(nvarchar(36),ArtifactContentId) FROM dmx.ArtifactContent WHERE Sha256=@Sha256;' -Parameters @{ '@Sha256'=$hash }
            if ($contentIdText) {
                $contentId = [Guid]$contentIdText
            }
            else {
                [byte[]]$original = [System.IO.File]::ReadAllBytes($Path)
                $memory = New-Object System.IO.MemoryStream
                try {
                    $gzip = New-Object System.IO.Compression.GZipStream($memory,[System.IO.Compression.CompressionMode]::Compress,$true)
                    try { $gzip.Write($original,0,$original.Length) } finally { $gzip.Dispose() }
                    [byte[]]$compressed = $memory.ToArray()
                }
                finally { $memory.Dispose() }
                $contentId=[Guid]::NewGuid()
                [void](Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
INSERT INTO dmx.ArtifactContent(ArtifactContentId,Sha256,OriginalLength,StoredLength,CompressionType,Content,CreatedAtUtc)
VALUES(@Id,@Sha256,@OriginalLength,@StoredLength,'GZip',@Content,SYSUTCDATETIME());
'@ -Parameters @{ '@Id'=$contentId; '@Sha256'=$hash; '@OriginalLength'=[long]$original.LongLength; '@StoredLength'=[long]$compressed.LongLength; '@Content'=$compressed })
            }
            if ($null -ne $ContentIdCache) { $ContentIdCache[$hash]=$contentId }
        }

        $artifactId=[Guid]::NewGuid()
        [void](Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
INSERT INTO dmx.Artifact(ArtifactId,RunId,ActionKey,ArtifactContentId,ArtifactType,OriginalFileName,MimeType,CreatedAtUtc)
VALUES(@Id,@RunId,@ActionKey,@ContentId,@ArtifactType,@FileName,@MimeType,SYSUTCDATETIME());
'@ -Parameters @{ '@Id'=$artifactId; '@RunId'=$RunId; '@ActionKey'=$(if($ActionKey){$ActionKey}else{[DBNull]::Value}); '@ContentId'=$contentId; '@ArtifactType'=$ArtifactType; '@FileName'=$file.Name; '@MimeType'=(Get-DynomaxMimeType -Path $Path) })
        return $artifactId
    }
    finally {
        if ($ownsConnection -and $activeConnection) { $activeConnection.Dispose() }
    }
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
SELECT ContextKey,ValueJson,IsSecret,CreatedAtUtc,UpdatedAtUtc
FROM dmx.RunContextValue
WHERE RunId=@RunId
ORDER BY ContextKey;
'@ -Parameters @{ '@RunId'=$RunId }

        $secretContextKeys=@{}
        foreach($contextRow in @($contextTable.Rows)){
            if([bool]$contextRow.IsSecret){$secretContextKeys[[string]$contextRow.ContextKey]=$true}
        }

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
            $actionOutput=ConvertFrom-DynomaxDbJson $_.OutputJson
            if($null -ne $actionOutput){
                foreach($secretKey in @($secretContextKeys.Keys)){
                    if($actionOutput.PSObject.Properties.Name -contains [string]$secretKey){
                        $actionOutput.PSObject.Properties.Remove([string]$secretKey)
                    }
                }
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
                output=$actionOutput
            }
        })

        $context = [ordered]@{}
        $safeRunDataPool=[pscustomobject][ordered]@{schemaVersion=1;steps=[pscustomobject][ordered]@{}}
        $runDataPoolStepPrefix='__dynomax.runDataPool.step.'
        foreach($row in $contextTable.Rows){
            if([bool]$row.IsSecret -or [string]$row.ContextKey -ne '__dynomax.runDataPool'){continue}
            $parsed=ConvertFrom-DynomaxDbJson $row.ValueJson
            if($null -ne $parsed -and $parsed.PSObject.Properties.Name -contains 'value' -and $null -ne $parsed.value){
                $safeRunDataPool=$parsed.value
                if($null -eq (Get-DynomaxPropertyValue -Object $safeRunDataPool -Name 'steps' -DefaultValue $null)){
                    Set-DynomaxContextObjectProperty -Object $safeRunDataPool -Name 'steps' -Value ([pscustomobject][ordered]@{})
                }
            }
        }
        foreach ($row in $contextTable.Rows) {
            if([bool]$row.IsSecret){continue}
            $contextKey=[string]$row.ContextKey
            $parsed = ConvertFrom-DynomaxDbJson $row.ValueJson
            if($contextKey -eq '__dynomax.runDataPool'){continue}
            if($contextKey.StartsWith($runDataPoolStepPrefix,[System.StringComparison]::Ordinal)){
                $safeStep=if($null -ne $parsed -and $parsed.PSObject.Properties.Name -contains 'value'){$parsed.value}else{$null}
                $stepId=[string](Get-DynomaxPropertyValue -Object $safeStep -Name 'stepId' -DefaultValue '')
                if(-not [string]::IsNullOrWhiteSpace($stepId)){
                    $steps=Get-DynomaxPropertyValue -Object $safeRunDataPool -Name 'steps' -DefaultValue $null
                    if($null -eq $steps){$steps=[pscustomobject][ordered]@{};Set-DynomaxContextObjectProperty -Object $safeRunDataPool -Name 'steps' -Value $steps}
                    Set-DynomaxContextObjectProperty -Object $steps -Name $stepId -Value $safeStep
                }
                continue
            }
            if ($null -ne $parsed -and $parsed.PSObject.Properties.Name -contains 'value') {$context[$contextKey] = $parsed.value}
            else { $context[$contextKey] = $parsed }
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

        $runWorkingDirectory = [string]$runRow.WorkingDirectory
        $attemptSummary = Get-DynomaxExecutionAttemptSummary -RunDirectory $runWorkingDirectory
        $attemptEvidencePath = Join-Path $runWorkingDirectory 'execution-attempts.jsonl'
        $orchestrationPerformancePath = Join-Path $runWorkingDirectory 'orchestration-performance.jsonl'

        $summary = [ordered]@{
            schemaVersion=3
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
            totalAttempts=[int]$attemptSummary.totalAttempts
            actionsRetried=[int]$attemptSummary.actionsRetried
            actionsRecoveredAfterRetry=[int]$attemptSummary.actionsRecoveredAfterRetry
            actionsWithExhaustedRetries=[int]$attemptSummary.actionsWithExhaustedRetries
        }

        Write-DynomaxJson -Value $summary -Path (Join-Path $OutputDirectory 'RunSummary.json')
        if(Test-Path -LiteralPath $attemptEvidencePath -PathType Leaf){Copy-Item -LiteralPath $attemptEvidencePath -Destination (Join-Path $OutputDirectory 'execution-attempts.jsonl') -Force}
        if(Test-Path -LiteralPath $orchestrationPerformancePath -PathType Leaf){Copy-Item -LiteralPath $orchestrationPerformancePath -Destination (Join-Path $OutputDirectory 'orchestration-performance.jsonl') -Force}
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=2;runId=[string]$RunId;actions=$actions}) -Path (Join-Path $OutputDirectory 'ActionResults.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;values=$context}) -Path (Join-Path $OutputDirectory 'ContextSnapshot.json')
        Write-DynomaxJson -Value ([ordered]@{schemaVersion=1;runId=[string]$RunId;dataPool=$safeRunDataPool}) -Path (Join-Path $OutputDirectory 'RunDataPool.json')
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
            "- Execution attempts: $($summary.totalAttempts)",
            "- Actions retried: $($summary.actionsRetried)",
            "- Recovered after retry: $($summary.actionsRecoveredAfterRetry)",
            "- Exhausted retries: $($summary.actionsWithExhaustedRetries)",
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
            '- execution-attempts.jsonl - structured attempt, delay, classification and evidence decisions.',
            '- orchestration-performance.jsonl - safe per-operation Dynomax runtime timing without Action input/output values.',
            '- ContextSnapshot.json - all non-secret persisted legacy context.',
            '- RunDataPool.json - exact step/output data pool with sensitive/non-persistable values redacted.',
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



function Copy-DynomaxAttemptRecorderEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$TestEvidenceDirectory
    )

    $source = Join-Path $RunDirectory 'attempt-recorder'
    if (-not (Test-Path -LiteralPath $source -PathType Container)) { return $false }
    $destination = Join-Path $TestEvidenceDirectory 'AttemptRecorder'
    if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }

    $retainedAttempts=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $attemptIndexPath=Join-Path $RunDirectory 'execution-attempts.jsonl'
    $indexAvailable=$false
    if(Test-Path -LiteralPath $attemptIndexPath -PathType Leaf){
        foreach($line in Get-Content -LiteralPath $attemptIndexPath -Encoding UTF8){
            if([string]::IsNullOrWhiteSpace($line)){continue}
            try{
                $attempt=$line|ConvertFrom-Json
                $stepOrder=[int](Get-DynomaxPropertyValue -Object $attempt -Name 'stepOrder' -DefaultValue 0)
                $attemptNumber=[int](Get-DynomaxPropertyValue -Object $attempt -Name 'attemptNumber' -DefaultValue 0)
                $status=[string](Get-DynomaxPropertyValue -Object $attempt -Name 'status' -DefaultValue '')
                $retained=[bool](Get-DynomaxPropertyValue -Object $attempt -Name 'evidenceRetained' -DefaultValue $false)
                if($stepOrder -gt 0 -and $attemptNumber -gt 0 -and ($status -ne 'PASS' -or $retained)){
                    [void]$retainedAttempts.Add(('{0}|{1}' -f $stepOrder,$attemptNumber))
                }
                $indexAvailable=$true
            }
            catch{
                # A malformed optional line must not erase all attempt diagnostics. Fall back to the
                # previous non-empty-file behaviour when the index cannot be trusted completely.
                $indexAvailable=$false
                $retainedAttempts.Clear()
                break
            }
        }
    }

    [System.IO.Directory]::CreateDirectory($destination) | Out-Null
    $copied = 0
    foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force) {
        if ($file.Length -le 0) { continue }
        $relative = Get-DynomaxRelativePath -BasePath $source -TargetPath $file.FullName
        if($indexAvailable){
            $parts=$relative -split '[\\/]'
            if($parts.Count -lt 3){continue}
            $attemptKey=('{0}|{1}' -f $parts[0],$parts[1])
            if(-not $retainedAttempts.Contains($attemptKey)){continue}
        }
        $target = Join-Path $destination $relative
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        $copied++
    }
    if ($copied -eq 0) {
        Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
    return $true
}
