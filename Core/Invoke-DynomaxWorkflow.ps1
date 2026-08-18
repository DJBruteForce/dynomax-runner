[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkflowDirectory,
    [string]$DynomaxConfigPath,
    [string]$RuntimeProjectFolder,
    [string]$ContextSeedPath,
    [string]$RunContractPath,
    [string]$CoreDiagnosticPath,
    [switch]$SuppressClipboard
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$current=[System.IO.Path]::GetFullPath($WorkflowDirectory)
while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent}
if(-not $current -or -not(Test-Path(Join-Path $current 'dynomax.json'))){throw 'Dynomax root not found.'}
$root=$current
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Process.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $root 'Core\Catalogue\Dynomax.Catalogue.ps1')
. (Join-Path $root 'Core\Results\Dynomax.Results.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.ExecutionPolicy.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.ControlFlow.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Workflow.ps1')


function ConvertTo-DynomaxBoundedDiagnosticMessage {
    param([object]$ErrorRecord,[int]$MaximumLength=2000)
    $message='Unknown Core finalization failure.'
    if($null -ne $ErrorRecord){
        if($ErrorRecord -is [System.Management.Automation.ErrorRecord]){$message=[string]$ErrorRecord.Exception.Message}
        elseif($ErrorRecord.PSObject.Properties['Exception']){$message=[string]$ErrorRecord.Exception.Message}
        else{$message=[string]$ErrorRecord}
    }
    $message=($message -replace '[\r\n\t]+',' ').Trim()
    if($message.Length -gt $MaximumLength){$message=$message.Substring(0,$MaximumLength)}
    return $message
}

function Write-DynomaxRunContractAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$ProjectKey,
        [Parameter(Mandatory)][string]$WorkflowId,
        [Parameter(Mandatory)][Guid]$WorkflowVersionId,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$LogicalStatus,
        [Parameter(Mandatory)][string]$FinalizationStatus,
        [Parameter(Mandatory)][string]$FinalizationStep,
        [AllowNull()][string]$ResultZipPath,
        [AllowNull()][string]$FailureCode,
        [AllowNull()][string]$FailureMessage
    )
    $resolved=[System.IO.Path]::GetFullPath($Path)
    $parent=Split-Path -Parent $resolved
    if($parent){[System.IO.Directory]::CreateDirectory($parent)|Out-Null}
    $contract=[ordered]@{
        schemaVersion=2
        runId=[string]$RunId
        projectKey=$ProjectKey
        workflowId=$WorkflowId
        workflowVersionId=[string]$WorkflowVersionId
        status=$Status
        logicalStatus=$LogicalStatus
        finalizationStatus=$FinalizationStatus
        finalizationStep=$FinalizationStep
        resultZipPath=$(if($ResultZipPath){$ResultZipPath}else{$null})
        failureCode=$(if($FailureCode){$FailureCode}else{$null})
        failureMessage=$(if($FailureMessage){$FailureMessage}else{$null})
        updatedAtUtc=[DateTime]::UtcNow.ToString('o')
        completedAtUtc=$(if($FinalizationStatus -in @('Completed','Recovered','Failed')){[DateTime]::UtcNow.ToString('o')}else{$null})
    }
    $temporary=$resolved+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    try{
        Write-DynomaxJson -Value $contract -Path $temporary
        Move-Item -LiteralPath $temporary -Destination $resolved -Force
    }
    finally{
        if(Test-Path -LiteralPath $temporary -PathType Leaf){Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue}
    }
}

function Test-DynomaxSqlEvidenceCandidate {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$File,
        [Parameter(Mandatory)][string]$RunDirectory
    )
    if($File.Name -eq 'context.json'){return $false}
    if($File.Length -le 0 -and $File.Extension -match '^\.(log|txt)$'){return $false}
    if($File.Extension -notmatch '^\.(xml|html?|log|png|jpe?g|pdf|json|jsonl|md|txt)$'){return $false}
    $relative=((Get-DynomaxRelativePath -BasePath $RunDirectory -TargetPath $File.FullName) -replace '\\','/').TrimStart('/')
    if($relative.StartsWith('attempt-recorder/',[System.StringComparison]::OrdinalIgnoreCase)){return $false}
    if($relative.StartsWith('robot-result/',[System.StringComparison]::OrdinalIgnoreCase)){
        if($relative -match '(?i)/(log|report)\.html$'){return $false}
        return $relative -match '(?i)/(output\.xml|playwright-log\.txt)$' -or $File.Extension -match '^\.(png|jpe?g)$'
    }
    if($relative.StartsWith('screenshots/',[System.StringComparison]::OrdinalIgnoreCase) -or
       $relative.StartsWith('discovery/',[System.StringComparison]::OrdinalIgnoreCase) -or
       $relative.StartsWith('attempt-evidence/',[System.StringComparison]::OrdinalIgnoreCase) -or
       $relative.StartsWith('downloads/',[System.StringComparison]::OrdinalIgnoreCase) -or
       $relative.StartsWith('documents/',[System.StringComparison]::OrdinalIgnoreCase) -or
       $relative.StartsWith('project-export/',[System.StringComparison]::OrdinalIgnoreCase)){
        return $true
    }
    return $relative -match '(?i)^(preflight\.json|core-diagnostics\.jsonl|control-flow-state\.json|orchestration-performance\.jsonl|execution-attempts\.jsonl|robot-console\.log|runtime-control-flow\.json|discovery-[^/]+\.json)$'
}

function Copy-DynomaxRobotResultEvidence {
    param(
        [Parameter(Mandatory)][string]$RobotResultDirectory,
        [Parameter(Mandatory)][string]$DestinationDirectory,
        [Parameter(Mandatory)][string]$LogicalStatus
    )
    if(-not(Test-Path -LiteralPath $RobotResultDirectory -PathType Container)){return 0}
    Ensure-DynomaxDirectory -Path $DestinationDirectory|Out-Null
    $names=New-Object System.Collections.Generic.List[string]
    $names.Add('output.xml')
    $names.Add('playwright-log.txt')
    if($LogicalStatus -ne 'PASS'){
        $names.Add('log.html')
        $names.Add('report.html')
    }
    $copied=0
    foreach($name in $names){
        $source=Join-Path $RobotResultDirectory $name
        if((Test-Path -LiteralPath $source -PathType Leaf) -and ((Get-Item -LiteralPath $source).Length -gt 0)){
            Copy-Item -LiteralPath $source -Destination (Join-Path $DestinationDirectory $name) -Force
            $copied++
        }
    }
    return $copied
}

if(-not $DynomaxConfigPath){$DynomaxConfigPath=Join-Path $root 'dynomax.json'}
$config=Read-DynomaxJson -Path $DynomaxConfigPath
$sqlConfigPath=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$sqlConfig=$databaseConfig.sql
$workflowPath=Join-Path $WorkflowDirectory 'workflow.json'
$workflow=Read-DynomaxJson -Path $workflowPath
$catalogueAlreadyPublished=[bool](Get-DynomaxPropertyValue -Object $workflow -Name 'catalogueAlreadyPublished' -DefaultValue $false)
if($RuntimeProjectFolder){
    $projectFolder=[System.IO.Path]::GetFullPath($RuntimeProjectFolder)
    if(-not(Test-Path -LiteralPath $projectFolder -PathType Container)){throw "Runtime project folder does not exist: $projectFolder"}
}else{
    $projectFolder=Get-DynomaxProjectFolder -DynomaxRoot $root -ProjectKey ([string]$workflow.projectKey)
}
$projectConfigPath=Join-Path $projectFolder 'Project-And-Config\project.json'
if(-not(Test-Path -LiteralPath $projectConfigPath -PathType Leaf)){throw "Runtime project definition does not exist: $projectConfigPath"}
$projectConfig=Read-DynomaxJson -Path $projectConfigPath

if($catalogueAlreadyPublished){
    $publishedWorkflowVersion=Get-DynomaxPropertyValue -Object $workflow -Name 'workflowVersionId' -DefaultValue $null
    $parsedWorkflowVersion=[Guid]::Empty
    if($null -eq $publishedWorkflowVersion -or -not [Guid]::TryParse([string]$publishedWorkflowVersion,[ref]$parsedWorkflowVersion)){
        throw 'A database-published workflow must contain a valid workflowVersionId.'
    }
    $workflowVersionId=$parsedWorkflowVersion
}else{
    Import-DynomaxProjectFolder -ProjectFolder $projectFolder -SqlConfig $sqlConfig
    $payloadFolder=Join-Path $WorkflowDirectory 'Payload'
    if(Test-Path $payloadFolder){Get-ChildItem -LiteralPath $payloadFolder -Filter action.json -File -Recurse|Sort-Object FullName|ForEach-Object{[void](Import-DynomaxActionDefinition -ActionJsonPath $_.FullName -SqlConfig $sqlConfig)}}
    $workflowVersionId=Import-DynomaxWorkflowDefinition -WorkflowJsonPath $workflowPath -SqlConfig $sqlConfig
}
$workflowVersionRecord=Get-DynomaxWorkflowVersionRecord -SqlConfig $sqlConfig -WorkflowVersionId $workflowVersionId -ProjectKey ([string]$workflow.projectKey) -WorkflowKey ([string]$workflow.workflowId)

$packageHash=Get-DynomaxSha256 -Path $workflowPath
$tempRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.tempRuns
$runDirectory=Ensure-DynomaxDirectory -Path (Join-Path $tempRoot ([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')))
$contextPath=Join-Path $runDirectory 'context.json'
$coreDiagnosticInternalPath=Join-Path $runDirectory 'core-diagnostics.jsonl'
$coreDiagnosticHandoffPath=$null
if(-not [string]::IsNullOrWhiteSpace([string]$CoreDiagnosticPath)){$coreDiagnosticHandoffPath=[System.IO.Path]::GetFullPath($CoreDiagnosticPath)}
$coreDiagnosticPaths=[System.Collections.Generic.List[string]]::new()
$coreDiagnosticPaths.Add($coreDiagnosticInternalPath)
if($coreDiagnosticHandoffPath -and -not [string]::Equals($coreDiagnosticHandoffPath,$coreDiagnosticInternalPath,[System.StringComparison]::OrdinalIgnoreCase)){$coreDiagnosticPaths.Add($coreDiagnosticHandoffPath)}
$coreRunRequestId=$null
$runRequestCandidateForDiagnostics=Split-Path -Leaf (Split-Path -Parent $WorkflowDirectory)
$parsedRunRequestForDiagnostics=[Guid]::Empty
if([Guid]::TryParse([string]$runRequestCandidateForDiagnostics,[ref]$parsedRunRequestForDiagnostics)){$coreRunRequestId=[string]$parsedRunRequestForDiagnostics}
function Write-DynomaxCoreDiagnostic {
    param(
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][string]$Stage,
        [Parameter(Mandatory)][string]$Message,
        [AllowNull()][Guid]$CoreRunId
    )
    try{
        $safe=(ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $Message -MaximumLength 4000)
        $entry=[ordered]@{
            timestampUtc=[DateTime]::UtcNow.ToString('o')
            level=$Level
            component='Core'
            stage=$Stage
            message=$safe
            runRequestId=$coreRunRequestId
            coreRunId=$(if($CoreRunId -and $CoreRunId -ne [Guid]::Empty){[string]$CoreRunId}else{$null})
            workflowKey=[string]$workflow.workflowId
        }
        $line=$entry|ConvertTo-Json -Depth 8 -Compress
        foreach($diagnosticPath in $coreDiagnosticPaths){
            try{
                $diagnosticParent=Split-Path -Parent $diagnosticPath
                if($diagnosticParent){[System.IO.Directory]::CreateDirectory($diagnosticParent)|Out-Null}
                [System.IO.File]::AppendAllText($diagnosticPath,$line+[Environment]::NewLine,[System.Text.UTF8Encoding]::new($false))
            }catch{}
        }
    }catch{}
}
Write-DynomaxCoreDiagnostic -Level 'Information' -Stage 'Startup' -Message 'Dynomax Core workflow startup began.' -CoreRunId ([Guid]::Empty)
$context=[ordered]@{schemaVersion=3;secretKeys=@();sensitiveKeys=@();values=[ordered]@{workflowBlocked=$false;projectKey=[string]$workflow.projectKey;environment=[string]$workflow.environment;workflowVersionId=[string]$workflowVersionId;workflowVersion=[int]$workflowVersionRecord.VersionNumber};runDataPool=[ordered]@{schemaVersion=1;steps=[ordered]@{}};stepInputs=[ordered]@{};runtimeValues=[ordered]@{};runtimePolicy=[ordered]@{};continuation=$null}
if($ContextSeedPath){
    $resolvedSeedPath=[System.IO.Path]::GetFullPath($ContextSeedPath)
    if(-not(Test-Path -LiteralPath $resolvedSeedPath -PathType Leaf)){throw "Context seed does not exist: $resolvedSeedPath"}
    $seed=Read-DynomaxJson -Path $resolvedSeedPath
    $seedSchema=[int](Get-DynomaxPropertyValue -Object $seed -Name 'schemaVersion' -DefaultValue 0); if($seedSchema -notin @(1,2,3)){throw 'Context seed schemaVersion must be 1, 2 or 3.'}
    $seedValues=Get-DynomaxPropertyValue -Object $seed -Name 'values' -DefaultValue $null
    if($null -eq $seedValues){throw 'Context seed values are required.'}
    $seedSecretKeys=@(Get-DynomaxPropertyValue -Object $seed -Name 'secretKeys' -DefaultValue @())
    $context.secretKeys=@($seedSecretKeys|ForEach-Object{[string]$_}|Where-Object{-not [string]::IsNullOrWhiteSpace($_)}|Sort-Object -Unique)
    foreach($property in @($seedValues.PSObject.Properties)){
        if([string]::IsNullOrWhiteSpace([string]$property.Name)){throw 'Context seed contains an empty key.'}
        $context.values[[string]$property.Name]=$property.Value
    }
    $seedStepInputs=Get-DynomaxPropertyValue -Object $seed -Name 'stepInputs' -DefaultValue $null
    if($null -ne $seedStepInputs){
        foreach($property in @($seedStepInputs.PSObject.Properties)){
            if([string]::IsNullOrWhiteSpace([string]$property.Name)){throw 'Context seed contains an empty step-input key.'}
            $context.stepInputs[[string]$property.Name]=$property.Value
        }
    }
    $seedRunDataPool=Get-DynomaxPropertyValue -Object $seed -Name 'runDataPool' -DefaultValue $null
    if($null -ne $seedRunDataPool){$context.runDataPool=$seedRunDataPool}
    $seedRuntimeValues=Get-DynomaxPropertyValue -Object $seed -Name 'runtimeValues' -DefaultValue $null
    if($null -ne $seedRuntimeValues){
        foreach($property in @($seedRuntimeValues.PSObject.Properties)){
            if([string]::IsNullOrWhiteSpace([string]$property.Name)){throw 'Context seed contains an empty runtime-value key.'}
            $context.runtimeValues[[string]$property.Name]=$property.Value
        }
    }
    $seedRuntimePolicy=Get-DynomaxPropertyValue -Object $seed -Name 'runtimePolicy' -DefaultValue $null
    if($null -ne $seedRuntimePolicy){
        if($seedRuntimePolicy -isnot [System.Management.Automation.PSCustomObject]){throw 'Context seed runtimePolicy must be a JSON object.'}
        $context.runtimePolicy=$seedRuntimePolicy
    }
    $seedContinuation=Get-DynomaxPropertyValue -Object $seed -Name 'continuation' -DefaultValue $null
    if($null -ne $seedContinuation){
        if($seedSchema -ne 3 -or $seedContinuation -isnot [System.Management.Automation.PSCustomObject]){throw 'Continuation context requires context seed schemaVersion 3 and a JSON object.'}
        $context.continuation=$seedContinuation
    }
}
Write-DynomaxJson -Value $context -Path $contextPath
$runId=New-DynomaxTestRun -SqlConfig $sqlConfig -ProjectKey ([string]$workflow.projectKey) -WorkflowKey ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -EnvironmentKey ([string]$workflow.environment) -WorkingDirectory $runDirectory -PackageHash $packageHash
Write-DynomaxCoreDiagnostic -Level 'Information' -Stage 'TestRunCreated' -Message 'Internal Core TestRun was created.' -CoreRunId $runId
$directPersistedContextCache=@{}
if($RunContractPath){
    try{
        Write-DynomaxRunContractAtomic -Path $RunContractPath -RunId $runId -ProjectKey ([string]$workflow.projectKey) -WorkflowId ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -Status 'RUNNING' -LogicalStatus 'RUNNING' -FinalizationStatus 'NotStarted' -FinalizationStep 'NotStarted' -ResultZipPath $null -FailureCode $null -FailureMessage $null
    }catch{Write-Warning ("Initial run-contract checkpoint failed: {0}" -f (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_))}
}
$context.values.runId=[string]$runId
$context.runtimeValues['RunId']=[string]$runId
$context.runtimeValues['EnvironmentKey']=[string]$workflow.environment
Write-DynomaxJson -Value $context -Path $contextPath

$allSteps=@($workflow.steps|Sort-Object order)
$stepPlans=@{}
$preflightException=$null
$outerRunRequestId=$null
$runRequestCandidate=Split-Path -Leaf (Split-Path -Parent $WorkflowDirectory)
$parsedOuterRunRequestId=[Guid]::Empty
if([Guid]::TryParse([string]$runRequestCandidate,[ref]$parsedOuterRunRequestId)){$outerRunRequestId=[string]$parsedOuterRunRequestId}
$context.runtimeValues['OperationId']=if($outerRunRequestId){$outerRunRequestId}else{[string]$runId}
Write-DynomaxJson -Value $context -Path $contextPath
$initialContext=Read-DynomaxJson -Path $contextPath
try{
    Write-DynomaxCoreDiagnostic -Level 'Debug' -Stage 'InitialContextPersistence' -Message 'Persisting initial Run context.' -CoreRunId $runId
    Set-DynomaxContextValuesInSql -SqlConfig $sqlConfig -RunId $runId -Context $initialContext -PersistedContextCache $directPersistedContextCache
    if($directPersistedContextCache.ContainsKey('__dynomax.contextBatchDisabled')){
        Write-DynomaxCoreDiagnostic -Level 'Warning' -Stage 'InitialContextPersistence' -Message ('Optimized context batch failed; deterministic per-key fallback is active. '+[string]$directPersistedContextCache['__dynomax.contextBatchDisabled']) -CoreRunId $runId
    }else{
        Write-DynomaxCoreDiagnostic -Level 'Debug' -Stage 'InitialContextPersistence' -Message 'Initial Run context persisted with optimized batch path.' -CoreRunId $runId
    }
}
catch{
    $startupMessage=ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_
    Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'InitialContextPersistence' -Message $startupMessage -CoreRunId $runId
    if($RunContractPath){
        try{
            Write-DynomaxRunContractAtomic -Path $RunContractPath -RunId $runId -ProjectKey ([string]$workflow.projectKey) -WorkflowId ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -Status 'ERROR' -LogicalStatus 'ERROR' -FinalizationStatus 'Failed' -FinalizationStep 'InitialContextPersistence' -ResultZipPath $null -FailureCode 'CORE_CONTEXT_INITIALIZATION_FAILED' -FailureMessage $startupMessage
        }catch{Write-Warning ("Startup failure run-contract checkpoint failed: {0}" -f (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_))}
    }
    throw
}
$preflightSummary=[ordered]@{
    schemaVersion=2
    status='PASS'
    classification=$null
    errorCode=$null
    runRequestId=$outerRunRequestId
    runId=[string]$runId
    workflowKey=[string]$workflow.workflowId
    workflowVersionId=[string]$workflowVersionId
    stepOrder=$null
    workflowNodeId=$null
    actionId=$null
    actionVersion=$null
    artifactType=$null
    artifactPath=$null
    artifactSource=$null
    requiredCoreVersion=$null
    installedCoreVersion=$null
    expectedDefinitionSha256=$null
    actualDefinitionSha256=$null
    expectedPackageSha256=$null
    actualPackageSha256=$null
    expectedEntryPointSha256=$null
    actualEntryPointSha256=$null
    expectedValue=$null
    actualValue=$null
    correctiveAction=$null
    message='Exact workflow and action-version preflight passed.'
    checkedAtUtc=[DateTime]::UtcNow.ToString('o')
}
Write-DynomaxCoreDiagnostic -Level 'Debug' -Stage 'Preflight' -Message 'Workflow and Action-version preflight began.' -CoreRunId $runId
try{
    Assert-DynomaxCoreRuntimeContract -DynomaxRoot $root
    $duplicateOrders=@($allSteps|Group-Object order|Where-Object{$_.Count -gt 1})
    if($duplicateOrders.Count -gt 0){
        $duplicateStep=@($duplicateOrders[0].Group)[0]
        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder ([int]$duplicateStep.order) -ActionKey ([string]$duplicateStep.actionId) -Message "Workflow step order '$($duplicateStep.order)' is duplicated. Exact result and version mapping requires unique step orders."
    }

    foreach($step in $allSteps){
        $plan=Resolve-DynomaxActionExecutionSource -ProjectFolder $projectFolder -ProjectKey ([string]$workflow.projectKey) -Step $step -SqlConfig $sqlConfig -WorkflowDirectory $WorkflowDirectory
        Set-DynomaxStepExecutionMetadata -Step $step -Plan $plan
        $actionDefinition=Read-DynomaxJson -Path ([string]$plan.DefinitionPath)
        [void](Assert-DynomaxStepExecutionPolicy -Step $step -ActionDefinition $actionDefinition -ActionVersionId ([Guid]$plan.ActionVersionId))
        $stepPlans[[string][int]$step.order]=$plan
    }
    Assert-DynomaxVersionPinnedSessionPlan -Steps $allSteps
}
catch{
    $preflightException=$_
    Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Preflight' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId
    $classification='ERROR'
    $stepOrder=if($_.Exception.Data.Contains('DynomaxStepOrder')){[int]$_.Exception.Data['DynomaxStepOrder']}else{0}
    $actionKey=if($_.Exception.Data.Contains('DynomaxActionKey')){[string]$_.Exception.Data['DynomaxActionKey']}else{'workflow.preflight'}
    if($_.Exception.Data.Contains('DynomaxClassification')){$classification=[string]$_.Exception.Data['DynomaxClassification']}
    $preflightSummary.status='FAILED'
    $preflightSummary.classification=$classification
    $preflightSummary.stepOrder=$stepOrder
    $preflightSummary.actionId=$actionKey
    $failedStep=@($allSteps|Where-Object{[int]$_.order -eq $stepOrder}|Select-Object -First 1)
    if($failedStep.Count -eq 1){
        $preflightSummary.workflowNodeId=[string](Get-DynomaxPropertyValue -Object $failedStep[0] -Name 'workflowNodeId' -DefaultValue '')
        $preflightSummary.actionVersion=Get-DynomaxPropertyValue -Object $failedStep[0] -Name 'actionVersion' -DefaultValue $null
        $builtInClosure=Get-DynomaxPropertyValue -Object $failedStep[0] -Name 'builtIn' -DefaultValue $null
        if($null -ne $builtInClosure){
            $preflightSummary.expectedDefinitionSha256=[string](Get-DynomaxPropertyValue -Object $builtInClosure -Name 'definitionSha256' -DefaultValue '')
            $preflightSummary.expectedPackageSha256=[string](Get-DynomaxPropertyValue -Object $builtInClosure -Name 'packageSha256' -DefaultValue '')
            $preflightSummary.expectedEntryPointSha256=[string](Get-DynomaxPropertyValue -Object $builtInClosure -Name 'entryPointSha256' -DefaultValue '')
            $preflightSummary.requiredCoreVersion=[string](Get-DynomaxPropertyValue -Object $builtInClosure -Name 'requiredCoreVersion' -DefaultValue '')
        }
    }
    $dataMap=@{
        'DynomaxErrorCode'='errorCode';'DynomaxWorkflowNodeId'='workflowNodeId';'DynomaxActionVersionNumber'='actionVersion';
        'DynomaxArtifactType'='artifactType';'DynomaxArtifactPath'='artifactPath';'DynomaxArtifactSource'='artifactSource';
        'DynomaxRequiredCoreVersion'='requiredCoreVersion';'DynomaxInstalledCoreVersion'='installedCoreVersion';
        'DynomaxExpectedDefinitionSha256'='expectedDefinitionSha256';'DynomaxActualDefinitionSha256'='actualDefinitionSha256';
        'DynomaxExpectedEntryPointSha256'='expectedEntryPointSha256';'DynomaxActualEntryPointSha256'='actualEntryPointSha256';
        'DynomaxExpectedValue'='expectedValue';'DynomaxActualValue'='actualValue';'DynomaxCorrectiveAction'='correctiveAction'
    }
    foreach($sourceKey in $dataMap.Keys){
        if($_.Exception.Data.Contains($sourceKey) -and $null -ne $_.Exception.Data[$sourceKey]){
            $preflightSummary[$dataMap[$sourceKey]]=[string]$_.Exception.Data[$sourceKey]
        }
    }
    $preflightSummary.message=$_.Exception.Message
}
Write-DynomaxJson -Value $preflightSummary -Path (Join-Path $runDirectory 'preflight.json')

$powerShell=if($PSVersionTable.PSEdition -eq 'Core'){$PSHOME+'\pwsh.exe'}else{$PSHOME+'\powershell.exe'}
$streamProcessOutput=[bool](Get-DynomaxPropertyValue -Object $config.logging -Name 'streamProcessOutput' -DefaultValue $true)
$showProcessCommands=[bool](Get-DynomaxPropertyValue -Object $config.logging -Name 'showProcessCommands' -DefaultValue $false)
$processHeartbeatSeconds=[int](Get-DynomaxPropertyValue -Object $config.logging -Name 'processHeartbeatSeconds' -DefaultValue 15)
$timeout=[int](Get-DynomaxPropertyValue -Object $workflow -Name 'timeoutSeconds' -DefaultValue 0)
$python=$null

function Set-DynomaxDynamicContextProperty {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string]$Name,$Value)
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property){
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }else{
        $property.Value=$Value
    }
}

function Get-DynomaxContinuationDecision {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId)
    $continuationContext=Read-DynomaxJson -Path $ContextPath
    $continuation=Get-DynomaxPropertyValue -Object $continuationContext -Name 'continuation' -DefaultValue $null
    if($null -eq $continuation){return 'EXECUTE'}
    $plan=Get-DynomaxPropertyValue -Object $continuation -Name 'plan' -DefaultValue $null
    if($null -eq $plan){throw 'Continuation context has no immutable plan.'}
    $matches=@((Get-DynomaxPropertyValue -Object $plan -Name 'items' -DefaultValue @())|Where-Object{
        [string](Get-DynomaxPropertyValue -Object $_ -Name 'targetStepId' -DefaultValue '') -ceq $StepId
    })
    if($matches.Count -ne 1){throw "Continuation plan has no unique decision for physical step '$StepId'."}
    $decision=([string](Get-DynomaxPropertyValue -Object $matches[0] -Name 'decision' -DefaultValue '')).ToUpperInvariant()
    if($decision -notin @('EXECUTE','REUSE','RERUNCONTEXT','INVALIDATED','BLOCKED')){throw "Continuation plan decision '$decision' is invalid."}
    return $decision
}

function Get-DynomaxRuntimeStepValue {
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)]$StepInput,[Parameter(Mandatory)][string]$Name,[int]$AttemptNumber=1)
    switch($Name){
        'CurrentUtc' { return [DateTime]::UtcNow.ToString('o') }
        'AttemptNumber' { return [int][Math]::Max(1,$AttemptNumber) }
        'NodePath' {
            $nodePath=[string](Get-DynomaxPropertyValue -Object $StepInput -Name 'nodePath' -DefaultValue '')
            if([string]::IsNullOrWhiteSpace($nodePath)){throw 'RuntimeValue NodePath is unavailable for this Action step.'}
            return $nodePath
        }
        default {
            $runtimeValues=Get-DynomaxPropertyValue -Object $Context -Name 'runtimeValues' -DefaultValue $null
            if($null -eq $runtimeValues){throw "RuntimeValue '$Name' is unavailable because runtimeValues is missing from the Run context."}
            $property=$runtimeValues.PSObject.Properties[$Name]
            if($null -eq $property -or $null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)){throw "RuntimeValue '$Name' is unavailable for this Run."}
            return $property.Value
        }
    }
}

function Refresh-DynomaxRuntimeStepInputContext {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId,[Parameter(Mandatory)][int]$AttemptNumber)
    $context=Read-DynomaxJson -Path $ContextPath
    $active=Get-DynomaxPropertyValue -Object $context -Name 'activeStepInput' -DefaultValue $null
    if($null -eq $active){return $false}
    if(-not [string]::Equals([string](Get-DynomaxPropertyValue -Object $active -Name 'stepId' -DefaultValue ''),$StepId,[StringComparison]::Ordinal)){throw 'The active Dynomax step-input scope belongs to a different execution slot.'}
    $stepInputs=Get-DynomaxPropertyValue -Object $context -Name 'stepInputs' -DefaultValue $null
    $entryProperty=if($null -ne $stepInputs){$stepInputs.PSObject.Properties[$StepId]}else{$null}
    if($null -eq $entryProperty){return $false}
    $entry=$entryProperty.Value
    $changed=$false
    foreach($binding in @(Get-DynomaxPropertyValue -Object $entry -Name 'deferredBindings' -DefaultValue @())){
        if([string](Get-DynomaxPropertyValue -Object $binding -Name 'kind' -DefaultValue '') -ne 'RuntimeValue'){continue}
        $inputName=[string](Get-DynomaxPropertyValue -Object $binding -Name 'inputName' -DefaultValue '')
        $name=[string](Get-DynomaxPropertyValue -Object $binding -Name 'name' -DefaultValue '')
        if(-not $inputName -or -not $name){throw 'A Dynomax runtime-value binding is incomplete.'}
        Set-DynomaxDynamicContextProperty -Object $context.values -Name $inputName -Value (Get-DynomaxRuntimeStepValue -Context $context -StepInput $entry -Name $name -AttemptNumber $AttemptNumber)
        $changed=$true
    }
    if($changed){
        $runtimeValues=Get-DynomaxPropertyValue -Object $context -Name 'runtimeValues' -DefaultValue $null
        if($null -ne $runtimeValues){
            Set-DynomaxDynamicContextProperty -Object $runtimeValues -Name 'AttemptNumber' -Value ([int][Math]::Max(1,$AttemptNumber))
            Set-DynomaxDynamicContextProperty -Object $runtimeValues -Name 'CurrentUtc' -Value ([DateTime]::UtcNow.ToString('o'))
        }
        Write-DynomaxJson -Value $context -Path $ContextPath
    }
    return $changed
}

function Get-DynomaxRunDataPoolOutputEntry {
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$SourceStepId,[Parameter(Mandatory)][string]$OutputName)
    $pool=Get-DynomaxPropertyValue -Object $Context -Name 'runDataPool' -DefaultValue $null
    $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
    $stepProperty=if($null -ne $steps){$steps.PSObject.Properties[$SourceStepId]}else{$null}
    if($null -eq $stepProperty){throw "Required Dynomax source step '$SourceStepId' has no captured outputs."}
    $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
    $outputProperty=if($null -ne $outputs){$outputs.PSObject.Properties[$OutputName]}else{$null}
    if($null -eq $outputProperty -or -not [bool](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'available' -DefaultValue $false)){
        throw "Required Dynomax output '$OutputName' from source step '$SourceStepId' is unavailable."
    }
    return $outputProperty.Value
}

function Get-DynomaxRunDataPoolOutputValue {
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$SourceStepId,[Parameter(Mandatory)][string]$OutputName)
    $entry=Get-DynomaxRunDataPoolOutputEntry -Context $Context -SourceStepId $SourceStepId -OutputName $OutputName
    return (Get-DynomaxPropertyValue -Object $entry -Name 'value' -DefaultValue $null)
}

function Enter-DynomaxStepInputContext {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId)
    $context=Read-DynomaxJson -Path $ContextPath
    $active=Get-DynomaxPropertyValue -Object $context -Name 'activeStepInput' -DefaultValue $null
    if($null -ne $active){throw 'A Dynomax step-input scope is already active; the previous Action did not restore its context.'}
    $stepInputs=Get-DynomaxPropertyValue -Object $context -Name 'stepInputs' -DefaultValue $null
    if($null -eq $stepInputs){return $false}
    $entryProperty=$stepInputs.PSObject.Properties[$StepId]
    if($null -eq $entryProperty){return $false}
    $entry=$entryProperty.Value
    $stepValues=Get-DynomaxPropertyValue -Object $entry -Name 'values' -DefaultValue $null
    $resolvedValues=[ordered]@{}
    $deferredSensitiveLookup=@{}
    if($null -ne $stepValues){foreach($property in @($stepValues.PSObject.Properties)){$resolvedValues[[string]$property.Name]=$property.Value}}
    foreach($binding in @(Get-DynomaxPropertyValue -Object $entry -Name 'deferredBindings' -DefaultValue @())){
        $kind=[string](Get-DynomaxPropertyValue -Object $binding -Name 'kind' -DefaultValue '')
        $inputName=[string](Get-DynomaxPropertyValue -Object $binding -Name 'inputName' -DefaultValue '')
        if(-not $inputName){throw 'A Dynomax deferred binding has no inputName.'}
        if($kind -eq 'StepOutput'){
            $sourceStepId=[string](Get-DynomaxPropertyValue -Object $binding -Name 'sourceStepId' -DefaultValue '')
            $sourceOutputName=[string](Get-DynomaxPropertyValue -Object $binding -Name 'sourceOutputName' -DefaultValue '')
            if(-not $sourceStepId -or -not $sourceOutputName){throw 'A Dynomax step-output binding is incomplete.'}
            $sourceOutput=Get-DynomaxRunDataPoolOutputEntry -Context $context -SourceStepId $sourceStepId -OutputName $sourceOutputName
            $resolvedValues[$inputName]=Get-DynomaxPropertyValue -Object $sourceOutput -Name 'value' -DefaultValue $null
            if([string](Get-DynomaxPropertyValue -Object $sourceOutput -Name 'classification' -DefaultValue 'Normal') -eq 'SensitiveRedacted'){$deferredSensitiveLookup[$inputName]=$true}
        }elseif($kind -eq 'RuntimeValue'){
            $name=[string](Get-DynomaxPropertyValue -Object $binding -Name 'name' -DefaultValue '')
            if(-not $name){throw 'A Dynomax runtime-value binding is incomplete.'}
            $resolvedValues[$inputName]=Get-DynomaxRuntimeStepValue -Context $context -StepInput $entry -Name $name -AttemptNumber 1
        }else{
            throw "Deferred Dynomax binding kind '$kind' is not supported by this Core release."
        }
    }
    if($resolvedValues.Count -eq 0){return $false}

    $secretLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$secretLookup[[string]$key]=$true}}
    $sensitiveLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$sensitiveLookup[[string]$key]=$true}}
    $stepSecretLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $entry -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$stepSecretLookup[[string]$key]=$true}}
    $stepSensitiveLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $entry -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$stepSensitiveLookup[[string]$key]=$true}}
    foreach($key in @($deferredSensitiveLookup.Keys)){$stepSensitiveLookup[[string]$key]=$true}
    $priorValues=[ordered]@{};$priorSecretFlags=[ordered]@{};$priorSensitiveFlags=[ordered]@{}
    foreach($name in @($resolvedValues.Keys)){
        $existing=$context.values.PSObject.Properties[$name]
        $priorValues[$name]=[ordered]@{exists=($null -ne $existing);value=$(if($null -ne $existing){$existing.Value}else{$null})}
        $priorSecretFlags[$name]=$secretLookup.ContainsKey($name)
        $priorSensitiveFlags[$name]=$sensitiveLookup.ContainsKey($name)
        Set-DynomaxDynamicContextProperty -Object $context.values -Name $name -Value $resolvedValues[$name]
        if($stepSecretLookup.ContainsKey($name)){$secretLookup[$name]=$true}else{[void]$secretLookup.Remove($name)}
        if($stepSensitiveLookup.ContainsKey($name) -or $stepSecretLookup.ContainsKey($name)){$sensitiveLookup[$name]=$true}else{[void]$sensitiveLookup.Remove($name)}
    }
    $context.secretKeys=@($secretLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $context -Name 'sensitiveKeys' -Value @($sensitiveLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $context -Name 'activeStepInput' -Value ([pscustomobject][ordered]@{stepId=$StepId;priorValues=[pscustomobject]$priorValues;priorSecretFlags=[pscustomobject]$priorSecretFlags;priorSensitiveFlags=[pscustomobject]$priorSensitiveFlags})
    Write-DynomaxJson -Value $context -Path $ContextPath
    return $true
}

function Exit-DynomaxStepInputContext {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId)
    $context=Read-DynomaxJson -Path $ContextPath
    $active=Get-DynomaxPropertyValue -Object $context -Name 'activeStepInput' -DefaultValue $null
    $secretLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$secretLookup[[string]$key]=$true}}
    $sensitiveLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$sensitiveLookup[[string]$key]=$true}}
    if($null -ne $active){
        if(-not [string]::Equals([string](Get-DynomaxPropertyValue -Object $active -Name 'stepId' -DefaultValue ''),$StepId,[StringComparison]::Ordinal)){throw 'The active Dynomax step-input scope belongs to a different execution slot.'}
        foreach($triple in @(
            @('priorValues','priorSecretFlags','priorSensitiveFlags'),
            @('priorOutputValues','priorOutputSecretFlags','priorOutputSensitiveFlags')
        )){
            $priorValues=Get-DynomaxPropertyValue -Object $active -Name $triple[0] -DefaultValue $null
            $priorSecretFlags=Get-DynomaxPropertyValue -Object $active -Name $triple[1] -DefaultValue $null
            $priorSensitiveFlags=Get-DynomaxPropertyValue -Object $active -Name $triple[2] -DefaultValue $null
            if($null -ne $priorValues){foreach($property in @($priorValues.PSObject.Properties)){
                $name=[string]$property.Name;$previous=$property.Value
                if([bool](Get-DynomaxPropertyValue -Object $previous -Name 'exists' -DefaultValue $false)){Set-DynomaxDynamicContextProperty -Object $context.values -Name $name -Value (Get-DynomaxPropertyValue -Object $previous -Name 'value' -DefaultValue $null)}else{[void]$context.values.PSObject.Properties.Remove($name)}
                $wasSecret=$false;if($null -ne $priorSecretFlags){$sp=$priorSecretFlags.PSObject.Properties[$name];if($null -ne $sp){$wasSecret=[bool]$sp.Value}}
                if($wasSecret){$secretLookup[$name]=$true}else{[void]$secretLookup.Remove($name)}
                $wasSensitive=$false;if($null -ne $priorSensitiveFlags){$sp=$priorSensitiveFlags.PSObject.Properties[$name];if($null -ne $sp){$wasSensitive=[bool]$sp.Value}}
                if($wasSensitive){$sensitiveLookup[$name]=$true}else{[void]$sensitiveLookup.Remove($name)}
            }}
        }
        [void]$context.PSObject.Properties.Remove('activeStepInput')
    }
    $pool=Get-DynomaxPropertyValue -Object $context -Name 'runDataPool' -DefaultValue $null
    $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
    $stepProperty=if($null -ne $steps){$steps.PSObject.Properties[$StepId]}else{$null}
    if($null -ne $stepProperty){
        $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
        if($null -ne $outputs){foreach($property in @($outputs.PSObject.Properties)){
            if([bool](Get-DynomaxPropertyValue -Object $property.Value -Name 'available' -DefaultValue $false)){
                $name=[string]$property.Name
                Set-DynomaxDynamicContextProperty -Object $context.values -Name $name -Value (Get-DynomaxPropertyValue -Object $property.Value -Name 'value' -DefaultValue $null)
                if([string](Get-DynomaxPropertyValue -Object $property.Value -Name 'classification' -DefaultValue 'Normal') -eq 'SensitiveRedacted'){$sensitiveLookup[$name]=$true}else{[void]$sensitiveLookup.Remove($name)}
            }
        }}
    }
    $context.secretKeys=@($secretLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $context -Name 'sensitiveKeys' -Value @($sensitiveLookup.Keys|Sort-Object)
    Write-DynomaxJson -Value $context -Path $ContextPath
}

function Invoke-DynomaxStepSequence {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Sequence)
    $index=0
    while($index -lt $Sequence.Count){
        $step=$Sequence[$index]
        $engine=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxEngine' -DefaultValue '')
        if($engine -eq 'RobotBrowser'){
            $block=[System.Collections.Generic.List[object]]::new()
            while($index -lt $Sequence.Count){
                $candidate=$Sequence[$index]
                $candidateEngine=[string](Get-DynomaxPropertyValue -Object $candidate -Name 'DynomaxEngine' -DefaultValue '')
                if($candidateEngine -ne 'RobotBrowser'){break}
                $block.Add($candidate);$index++
            }
            $blockSteps=$block.ToArray()
            $process=Invoke-DynomaxRobotBlock -DynomaxRoot $root -ProjectFolder $projectFolder -ProjectConfig $projectConfig -Workflow $workflow -Steps $blockSteps -RunId $runId -RunDirectory $runDirectory -ContextPath $contextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -PythonPath $python -TimeoutSeconds $timeout -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds
            $outputXml=Join-Path $runDirectory 'robot-result\output.xml'
            if(-not(Test-Path $outputXml)){throw "Robot did not produce output.xml. Exit code: $($process.ExitCode). Error: $($process.StandardError)"}
            if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
                if(Test-Path -LiteralPath $statePath -PathType Leaf){
                    $state=Read-DynomaxJson -Path $statePath
                    $terminalStatus=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
                    $containsMainStep=@($blockSteps|Where-Object{-not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)}).Count -gt 0
                    if($terminalStatus -and $containsMainStep){
                        # Robot locally skips the remaining pre-unrolled physical tests after terminal
                        # control flow without spawning persistence subprocesses. Fill every missing
                        # main-sequence physical ActionRun row here, then stop scheduling this sequence.
                        [void](Add-DynomaxMissingControlFlowActionRuns -SqlConfig $sqlConfig -RunId $runId -Steps $Sequence -ContextPath $contextPath)
                        $index=$Sequence.Count
                    }
                }
            }
        }
        elseif($engine -eq 'PowerShell'){
            $disposition='RUN'
            $logicalNodeId=[string](Get-DynomaxPropertyValue -Object $step -Name 'workflowNodeId' -DefaultValue ([string]$step.stepId))
            if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                $decision=Get-DynomaxControlFlowDecision -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory -NodeId $logicalNodeId
                $disposition=[string]$decision.Disposition
            }
            if($disposition -eq 'RUN'){
                $continuationDecision=Get-DynomaxContinuationDecision -ContextPath $contextPath -StepId ([string]$step.stepId)
                if($continuationDecision -eq 'BLOCKED'){
                    throw "Continuation is blocked at physical step '$([string]$step.stepId)'. Inspect the immutable continuation plan for the safety reason."
                }
                if($continuationDecision -eq 'REUSE'){
                    Add-DynomaxRunEvent -SqlConfig $sqlConfig -RunId $runId -EventLevel 'Info' -EventType 'Continuation.Reused' -Message "Physical step '$([string]$step.stepId)' was reused from the source Run; no Action executed." -Data ([ordered]@{stepId=[string]$step.stepId;workflowNodeId=$logicalNodeId;actionKey=[string]$step.actionId;executionKind='Reused';executed=$false})
                    if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                        $reuseState=Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory -NodeId $logicalNodeId -Reused -DeferStateWrite
                        [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory -State $reuseState)
                    }
                    $postReuseContext=Read-DynomaxJson -Path $contextPath
                    Set-DynomaxContextStepInSql -SqlConfig $sqlConfig -RunId $runId -Context $postReuseContext -StepId ([string]$step.stepId) -PersistedContextCache $directPersistedContextCache
                }else{
                $stepInputsActivated=$false
                $stepFailure=$null
                try{
                    $stepInputsActivated=[bool](Enter-DynomaxStepInputContext -ContextPath $contextPath -StepId ([string]$step.stepId))
                    try{
                        [void](Invoke-DynomaxPowerShellAction -DynomaxRoot $root -ProjectFolder $projectFolder -RunId $runId -Step $step -ContextPath $contextPath -RunDirectory $runDirectory -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -SqlConfig $sqlConfig -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds)
                    }catch{
                        $stepFailure=$_
                    }
                }finally{
                    if($stepInputsActivated){Exit-DynomaxStepInputContext -ContextPath $contextPath -StepId ([string]$step.stepId)}
                    $postStepContext=Read-DynomaxJson -Path $contextPath
                    Set-DynomaxContextStepInSql -SqlConfig $sqlConfig -RunId $runId -Context $postStepContext -StepId ([string]$step.stepId) -PersistedContextCache $directPersistedContextCache
                }
                if($null -ne $stepFailure){
                    if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                        $failureState=Fail-DynomaxControlFlowAction -Workflow $workflow -RunDirectory $runDirectory -NodeId $logicalNodeId -DeferStateWrite
                        [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory -State $failureState)
                    }
                    throw $stepFailure
                }
                if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                    # Evaluate downstream control flow only after step-local inputs are restored.
                    $completionState=Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory -NodeId $logicalNodeId -DeferStateWrite
                    [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory -State $completionState)
                }
                }
            }
            elseif($disposition -eq 'SKIP_FINAL'){
                $versionId=[Guid][string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue [Guid]::Empty)
                Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $runId -StepOrder ([int]$step.order) -ActionKey ([string]$step.actionId) -ActionVersionId $versionId -Status 'SKIPPED' -Message 'Action was not selected by Workflow control flow.'
            }
            elseif($disposition -ne 'DEFER'){
                throw "Unsupported control-flow disposition '$disposition' for '$logicalNodeId'."
            }
            if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
                if(Test-Path -LiteralPath $statePath -PathType Leaf){
                    $state=Read-DynomaxJson -Path $statePath
                    $terminalStatus=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
                    $isMainStep=-not [bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)
                    if($terminalStatus -and $isMainStep){
                        [void](Add-DynomaxMissingControlFlowActionRuns -SqlConfig $sqlConfig -RunId $runId -Steps $Sequence -ContextPath $contextPath)
                        $index=$Sequence.Count
                        continue
                    }
                }
            }
            $index++
        }
        else{throw "Unsupported action engine '$engine' for '$($step.actionId)'."}
    }
}


function Test-DynomaxPreservedCleanupBrowserSessionEligible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$MainSteps,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$CleanupSteps
    )
    if($MainSteps.Count -eq 0 -or $CleanupSteps.Count -eq 0){return $false}
    $combined=@($MainSteps)+@($CleanupSteps)
    foreach($step in $combined){
        if([string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxEngine' -DefaultValue '') -ne 'RobotBrowser'){return $false}
    }
    # RequiresNewBrowser on any Cleanup step is an explicit isolation request. Otherwise the
    # existing Main browser/context remains authoritative through Cleanup.
    foreach($step in $CleanupSteps){
        if([string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxSessionBehavior' -DefaultValue 'DoesNotUseBrowser') -eq 'RequiresNewBrowser'){return $false}
    }
    return $true
}

function Invoke-DynomaxPreservedBrowserMainAndCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$MainSteps,
        [Parameter(Mandatory)][object[]]$CleanupSteps
    )
    $combined=@($MainSteps)+@($CleanupSteps)
    Add-DynomaxRunEvent -SqlConfig $sqlConfig -RunId $runId -EventLevel 'Info' -EventType 'Runtime.CleanupBrowserSessionPreserved' -Message 'Cleanup will continue in the existing Main Robot browser/context.' -Data ([ordered]@{mode='Preserve';mainStepCount=$MainSteps.Count;cleanupStepCount=$CleanupSteps.Count})
    $process=Invoke-DynomaxRobotBlock -DynomaxRoot $root -ProjectFolder $projectFolder -ProjectConfig $projectConfig -Workflow $workflow -Steps $combined -RunId $runId -RunDirectory $runDirectory -ContextPath $contextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -PythonPath $python -TimeoutSeconds $timeout -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds -PreserveCleanupBrowserSession:$true
    $outputXml=Join-Path $runDirectory 'robot-result\output.xml'
    if(-not(Test-Path $outputXml)){throw "Robot did not produce output.xml. Exit code: $($process.ExitCode). Error: $($process.StandardError)"}
    if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
        $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
        if(Test-Path -LiteralPath $statePath -PathType Leaf){
            $state=Read-DynomaxJson -Path $statePath
            $terminalStatus=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
            if($terminalStatus){
                # Main control-flow terminalization and StopCleanup are bookkeeping boundaries, not
                # executable Actions. Fill the remaining immutable physical-slot evidence in bounded
                # SQL batches after Robot returns instead of making Robot visit every unused slot.
                [void](Add-DynomaxMissingControlFlowActionRuns -SqlConfig $sqlConfig -RunId $runId -Steps $MainSteps -ContextPath $contextPath -IsCleanup:$false)
                $connection=Open-DynomaxConnection -SqlConfig $sqlConfig
                try{
                    $cleanupFailureCount=[int](Invoke-DynomaxSqlScalar -Connection $connection -CommandText "SELECT COUNT(*) FROM dmx.ActionRun WHERE RunId=@RunId AND IsCleanup=1 AND Status=N'CLEANUP_FAILED';" -Parameters @{ '@RunId'=$runId })
                }finally{$connection.Dispose()}
                if($cleanupFailureCount -gt 0){
                    [void](Add-DynomaxMissingControlFlowActionRuns -SqlConfig $sqlConfig -RunId $runId -Steps $CleanupSteps -ContextPath $contextPath -Message 'Cleanup stopped after the first failed Cleanup Action because continueOnFailure is false.' -IsCleanup:$true)
                }
            }
        }
    }
}

$mainSteps=@($allSteps|Where-Object{-not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)})
$cleanupSteps=@($allSteps|Where-Object{[bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)}|Sort-Object order -Descending)
$overall='ERROR'
$executionException=$null
$cleanupException=$null
$resultZipPath=$null

Write-DynomaxCoreDiagnostic -Level 'Information' -Stage 'Execution' -Message 'Workflow execution phase began.' -CoreRunId $runId
try{
    if($preflightException){
        $classification=[string]$preflightSummary.classification
        $problemOrder=[int]$preflightSummary.stepOrder
        $problemAction=[string]$preflightSummary.actionId
        $problemVersionId=[Guid]::Empty
        if($preflightException.Exception.Data.Contains('DynomaxActionVersionId')){$problemVersionId=[Guid][string]$preflightException.Exception.Data['DynomaxActionVersionId']}
        if($problemVersionId -ne [Guid]::Empty){
            Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $runId -StepOrder $problemOrder -ActionKey $problemAction -ActionVersionId $problemVersionId -Status $classification -Message $preflightSummary.message
        }
        else{
            Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $runId -StepOrder $problemOrder -ActionKey $problemAction -Status $classification -Message $preflightSummary.message -AllowUnresolvedActionVersion
        }
        $overall=$classification
        $executionException=$preflightException
        Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary ("Workflow preflight failed before execution: {0}" -f $preflightSummary.message)
    }
    else{
        $prereq=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.prerequisiteConfig)
        $python=Resolve-DynomaxCommand -Candidates @($prereq.pythonCommandCandidates)
        if(-not $python){throw 'Python was not found. Run prerequisite setup.'}

        if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
            [void](Initialize-DynomaxControlFlowState -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory)
            Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory
        }
        $alwaysRunCleanup=[bool](Get-DynomaxPropertyValue -Object $workflow -Name 'alwaysRunCleanup' -DefaultValue $true)
        $preserveCleanupBrowserSession=$alwaysRunCleanup -and (Test-DynomaxPreservedCleanupBrowserSessionEligible -MainSteps $mainSteps -CleanupSteps $cleanupSteps)
        if($preserveCleanupBrowserSession){
            try{Invoke-DynomaxPreservedBrowserMainAndCleanup -MainSteps $mainSteps -CleanupSteps $cleanupSteps}catch{$executionException=$_;Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Main' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId}
        }
        else{
            try{Invoke-DynomaxStepSequence -Sequence $mainSteps}catch{$executionException=$_;Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Main' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId}
            if($alwaysRunCleanup -and $cleanupSteps.Count -gt 0){
                try{Invoke-DynomaxStepSequence -Sequence $cleanupSteps}catch{$cleanupException=$_;Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Cleanup' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId}
            }
        }
        $overall=Get-DynomaxOverallStatus -SqlConfig $sqlConfig -RunId $runId
        if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
            $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
            if(Test-Path -LiteralPath $statePath -PathType Leaf){
                $controlState=Read-DynomaxJson -Path $statePath
                $terminalStatus=[string](Get-DynomaxPropertyValue -Object $controlState -Name 'terminalStatus' -DefaultValue '')
                if($terminalStatus -eq 'FAIL'){$overall='FAIL'}
                elseif($terminalStatus -eq 'PASS' -and -not $executionException){$overall='PASS'}
                elseif(-not $terminalStatus -and -not $executionException){$overall='ERROR';$executionException=[pscustomobject]@{Exception=[System.InvalidOperationException]::new('Workflow control flow did not reach a terminal node.')}}
            }
        }
        if($cleanupException -and $overall -eq 'PASS'){$overall='CLEANUP_FAILED'}
        if($executionException -and $overall -eq 'PASS'){$overall='ERROR'}
        $message="Workflow '$($workflow.displayName)' completed with status $overall."
        if($executionException){$message += " Execution error: $($executionException.Exception.Message)"}
        if($cleanupException){$message += " Cleanup error: $($cleanupException.Exception.Message)"}
        Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary $message
    }
}
catch{
    $executionException=$_
    $overall='ERROR'
    $executionMessage=ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_
    Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Unhandled' -Message $executionMessage -CoreRunId $runId
    try{
        Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary ("Workflow execution failed before normal Action completion: {0}" -f $executionMessage)
    }catch{
        Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Persistence' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId
    }
}
finally{
    $logicalStatus=[string]$overall
    $finalizationStatus='Running'
    $finalizationStep='Starting'
    $finalizationFailureCode=$null
    $finalizationFailureMessage=$null
    function Set-DynomaxFinalizationStep {
        param([Parameter(Mandatory)][string]$Step)
        $script:finalizationStep=$Step
        Write-DynomaxCoreDiagnostic -Level 'Debug' -Stage ('Finalization.'+$Step) -Message ('Result finalization entered step '+$Step+'.') -CoreRunId $runId
        if($RunContractPath){
            try{
                Write-DynomaxRunContractAtomic -Path $RunContractPath -RunId $runId -ProjectKey ([string]$workflow.projectKey) -WorkflowId ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -Status 'RUNNING' -LogicalStatus $logicalStatus -FinalizationStatus $finalizationStatus -FinalizationStep $Step -ResultZipPath $null -FailureCode $null -FailureMessage $null
            }catch{Write-Warning ("Finalization run-contract checkpoint failed at '{0}': {1}" -f $Step,(ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_))}
        }
    }
    Set-DynomaxFinalizationStep -Step 'Starting'
    try{
        Set-DynomaxFinalizationStep -Step 'FinalContextCheckpoint'
        if(Test-Path $contextPath){try{$finalContext=Read-DynomaxJson -Path $contextPath;Set-DynomaxContextValuesInSql -SqlConfig $sqlConfig -RunId $runId -Context $finalContext -PersistedContextCache $directPersistedContextCache}catch{Write-Warning $_.Exception.Message}}

    Set-DynomaxFinalizationStep -Step 'SqlEvidenceIngestion'
    $artifactIngestionSucceeded=$true
    $max=[long]$config.execution.maximumSqlArtifactBytes
    $artifactConnection=$null
    $artifactContentCache=@{}
    try{
        $artifactConnection=Open-DynomaxConnection -SqlConfig $sqlConfig
        foreach($evidenceFile in Get-ChildItem -LiteralPath $runDirectory -File -Recurse -ErrorAction SilentlyContinue){
            if(-not(Test-DynomaxSqlEvidenceCandidate -File $evidenceFile -RunDirectory $runDirectory)){continue}
            try{
                [void](Add-DynomaxArtifact -SqlConfig $sqlConfig -RunId $runId -ArtifactType 'RunEvidence' -Path $evidenceFile.FullName -MaximumBytes $max -Connection $artifactConnection -ContentIdCache $artifactContentCache)
            }
            catch{
                $artifactIngestionSucceeded=$false
                Write-Warning ("Artifact ingestion failed for '{0}': {1}" -f $evidenceFile.FullName,$_.Exception.Message)
            }
        }
    }
    finally{if($null -ne $artifactConnection){$artifactConnection.Dispose()}}

    Set-DynomaxFinalizationStep -Step 'PrepareExportStaging'
    $exportRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.exports
    Ensure-DynomaxDirectory -Path $exportRoot|Out-Null
    $stagingRoot=Ensure-DynomaxDirectory -Path (Join-Path $exportRoot ('.staging\'+[string]$runId))
    if(Test-Path $stagingRoot){Get-ChildItem -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue}

    Set-DynomaxFinalizationStep -Step 'ExportRunSummary'
    try{[void](Export-DynomaxRunSummary -SqlConfig $sqlConfig -RunId $runId -OutputDirectory $stagingRoot)}catch{$artifactIngestionSucceeded=$false;Write-Warning $_.Exception.Message}

    Set-DynomaxFinalizationStep -Step 'CopyEvidence'
    $projectExport=Join-Path $runDirectory 'project-export'
    if(Test-Path -LiteralPath $projectExport -PathType Container){
        Copy-Item -LiteralPath $projectExport -Destination (Join-Path $stagingRoot 'ProjectFindings') -Recurse -Force
    }

    $testEvidence=Ensure-DynomaxDirectory -Path (Join-Path $stagingRoot 'TestEvidence')
    $robotResult=Join-Path $runDirectory 'robot-result'
    [void](Copy-DynomaxRobotResultEvidence -RobotResultDirectory $robotResult -DestinationDirectory (Join-Path $testEvidence 'Robot') -LogicalStatus $logicalStatus)
    $rootEvidenceNames=@(
        'preflight.json',
        'core-diagnostics.jsonl',
        'control-flow-state.json',
        'orchestration-performance.jsonl',
        'execution-attempts.jsonl',
        'robot-console.log'
    )
    if($logicalStatus -ne 'PASS'){$rootEvidenceNames+=@('generated-workflow.robot')}
    foreach($name in $rootEvidenceNames){
        $source=Join-Path $runDirectory $name
        if((Test-Path -LiteralPath $source -PathType Leaf) -and ((Get-Item -LiteralPath $source).Length -gt 0)){
            Copy-Item -LiteralPath $source -Destination (Join-Path $testEvidence $name) -Force
        }
    }
    $screenshots=Join-Path $runDirectory 'screenshots'
    if(Test-Path $screenshots){Copy-Item -LiteralPath $screenshots -Destination (Join-Path $testEvidence 'Screenshots') -Recurse -Force}
    $documentsEvidence=Ensure-DynomaxDirectory -Path (Join-Path $testEvidence 'Documents')
    foreach($documentRootName in @('downloads','documents')){
        $documentRoot=Join-Path $runDirectory $documentRootName
        if(-not(Test-Path -LiteralPath $documentRoot -PathType Container)){continue}
        foreach($documentFile in Get-ChildItem -LiteralPath $documentRoot -File -Recurse -ErrorAction SilentlyContinue){
            if($documentFile.Extension -notmatch '(?i)^\.pdf$'){continue}
            $relativeDocument=(Get-DynomaxRelativePath -BasePath $documentRoot -TargetPath $documentFile.FullName) -replace '\\','/'
            $destinationRoot=Ensure-DynomaxDirectory -Path (Join-Path $documentsEvidence $documentRootName)
            $destination=Join-Path $destinationRoot ($relativeDocument -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            $destinationDirectory=Split-Path -Parent $destination
            if($destinationDirectory){[void](Ensure-DynomaxDirectory -Path $destinationDirectory)}
            Copy-Item -LiteralPath $documentFile.FullName -Destination $destination -Force
        }
    }
    $discoveryEvidence=Join-Path $runDirectory 'discovery'
    if(Test-Path $discoveryEvidence){Copy-Item -LiteralPath $discoveryEvidence -Destination (Join-Path $testEvidence 'Discovery') -Recurse -Force}
    $attemptEvidence=Join-Path $runDirectory 'attempt-evidence'
    if(Test-Path $attemptEvidence){Copy-Item -LiteralPath $attemptEvidence -Destination (Join-Path $testEvidence 'Attempts') -Recurse -Force}
    [void](Copy-DynomaxAttemptRecorderEvidence -RunDirectory $runDirectory -TestEvidenceDirectory $testEvidence)

    Set-DynomaxFinalizationStep -Step 'CopyDefinitions'
    $definitions=Ensure-DynomaxDirectory -Path (Join-Path $stagingRoot 'Definitions')
    $projectDefinitionDir=Ensure-DynomaxDirectory -Path (Join-Path $definitions 'Project')
    Copy-Item -LiteralPath $projectConfigPath -Destination (Join-Path $projectDefinitionDir 'project.json') -Force
    $workflowDefinitionDir=Ensure-DynomaxDirectory -Path (Join-Path $definitions 'Workflow')
    Copy-Item -LiteralPath $workflowPath -Destination (Join-Path $workflowDefinitionDir 'workflow.json') -Force
    $manifestActions=@()
    $copiedActionDefinitions=@{}
    foreach($step in $allSteps){
        $planKey=[string][int]$step.order
        $requested=Get-DynomaxPropertyValue -Object $step -Name 'actionVersion' -DefaultValue $null
        if($stepPlans.ContainsKey($planKey)){
            $plan=$stepPlans[$planKey]
            $versionKey=[string]$plan.ActionVersionId
            $definitionRelativePath=$null
            if(-not $copiedActionDefinitions.ContainsKey($versionKey)){
                $safe=([string]$step.actionId -replace '[^A-Za-z0-9_.-]','_')
                $shortVersionId=([string]$plan.ActionVersionId -replace '-','').Substring(0,12)
                $definitionRelativePath=("Actions/{0}-v{1}-{2}" -f $safe,[int]$plan.ResolvedActionVersion,$shortVersionId)
                $actionDestination=Join-Path $definitions ($definitionRelativePath -replace '/','\')
                Ensure-DynomaxDirectory -Path $actionDestination|Out-Null
                foreach($sourceFile in Get-ChildItem -LiteralPath $plan.Folder -File){Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $actionDestination $sourceFile.Name) -Force}
                $copiedActionDefinitions[$versionKey]=$definitionRelativePath
            }
            else{$definitionRelativePath=[string]$copiedActionDefinitions[$versionKey]}
            $manifestActions += [ordered]@{
                order=[int]$step.order
                actionId=[string]$step.actionId
                cleanup=[bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)
                requestedActionVersion=$(if($null -eq $plan.RequestedActionVersion){$null}else{[int]$plan.RequestedActionVersion})
                resolvedActionVersion=[int]$plan.ResolvedActionVersion
                actionVersionId=[string]$plan.ActionVersionId
                definitionRelativePath=$definitionRelativePath
                engine=[string]$plan.Engine
                entryPoint=[string]$plan.EntryPoint
                sessionBehavior=[string]$plan.SessionBehavior
                sourceLocation=[string]$plan.SourceLocation
                sourceVerified=[bool]$plan.SourceVerified
                resolutionStatus='Resolved'
                catalogueDefinitionHash=[string]$plan.DefinitionHash
                catalogueImplementationHash=[string]$plan.ImplementationHash
                actionDefinitionSha256=[string]$plan.DefinitionFileSha256
                implementationSha256=Get-DynomaxSha256 -Path $plan.EntryPointPath
            }
        }
        else{
            $manifestActions += [ordered]@{
                order=[int]$step.order
                actionId=[string]$step.actionId
                cleanup=[bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)
                requestedActionVersion=$(if($null -eq $requested){$null}else{[int]$requested})
                resolvedActionVersion=$null
                actionVersionId=$null
                definitionRelativePath=$null
                engine=$null
                entryPoint=$null
                sessionBehavior=$null
                sourceLocation=$null
                sourceVerified=$false
                resolutionStatus='Unresolved'
                resolutionMessage=$(if([int]$preflightSummary.stepOrder -eq [int]$step.order){[string]$preflightSummary.message}else{'Not resolved because workflow preflight stopped before execution.'})
                catalogueDefinitionHash=$null
                catalogueImplementationHash=$null
                actionDefinitionSha256=$null
                implementationSha256=$null
            }
        }
    }
    Set-DynomaxFinalizationStep -Step 'WriteWorkflowManifest'
    $workflowManifest=[ordered]@{
        schemaVersion=2
        runId=[string]$runId
        frameworkVersion=[string]$config.frameworkVersion
        projectKey=[string]$workflow.projectKey
        environment=[string]$workflow.environment
        workflowId=[string]$workflow.workflowId
        workflowVersionId=[string]$workflowVersionRecord.WorkflowVersionId
        workflowVersion=[int]$workflowVersionRecord.VersionNumber
        exactWorkflowVersionPinned=$true
        exactActionVersionsPinned=(@($allSteps | Where-Object {
            $value=Get-DynomaxPropertyValue -Object $_ -Name 'actionVersion' -DefaultValue $null
            $null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)
        }).Count -eq $allSteps.Count)
        workflowDefinitionHash=[string]$workflowVersionRecord.DefinitionHash
        workflowDefinitionSha256=Get-DynomaxSha256 -Path $workflowPath
        projectDefinitionSha256=Get-DynomaxSha256 -Path $projectConfigPath
        preflight=$preflightSummary
        uniqueActionDefinitionCount=[int]$copiedActionDefinitions.Count
        physicalActionSlotCount=[int]$allSteps.Count
        actions=$manifestActions
    }
    Write-DynomaxJson -Value $workflowManifest -Path (Join-Path $stagingRoot 'WorkflowManifest.json')

    Set-DynomaxFinalizationStep -Step 'CleanupTemporaryWorkspace'
    $cleanupRequested=[bool](Get-DynomaxPropertyValue -Object $config.execution -Name 'deleteTemporaryRunAfterSuccessfulIngestion' -DefaultValue $true)
    $temporaryCleanup=[ordered]@{requested=$cleanupRequested;attempted=$false;succeeded=$false;path=$runDirectory;reason=$null;verifiedAtUtc=$null}
    if($cleanupRequested -and $artifactIngestionSucceeded){
        $temporaryCleanup.attempted=$true
        try{
            Remove-Item -LiteralPath $runDirectory -Recurse -Force
            $temporaryCleanup.succeeded=-not(Test-Path -LiteralPath $runDirectory)
            if(-not $temporaryCleanup.succeeded){$temporaryCleanup.reason='Temporary run directory still exists after deletion.'}
        }catch{$temporaryCleanup.reason=$_.Exception.Message}
    }
    elseif(-not $artifactIngestionSucceeded){$temporaryCleanup.reason='Temporary files retained because SQL artifact ingestion or export preparation reported a failure.'}
    else{$temporaryCleanup.reason='Temporary cleanup disabled by configuration.'}
    $temporaryCleanup.verifiedAtUtc=[DateTime]::UtcNow.ToString('o')
    Write-DynomaxJson -Value $temporaryCleanup -Path (Join-Path $stagingRoot 'TemporaryWorkspaceCleanup.json')

    Set-DynomaxFinalizationStep -Step 'WriteExportManifest'
    [void](Write-DynomaxExportManifest -ExportDirectory $stagingRoot -RunId $runId -FrameworkVersion ([string]$config.frameworkVersion) -TemporaryCleanup $temporaryCleanup)

    Set-DynomaxFinalizationStep -Step 'BuildResultZip'
    if([bool](Get-DynomaxPropertyValue -Object $config.execution -Name 'createResultZip' -DefaultValue $true)){
        $safeProject=([string]$workflow.projectKey -replace '[^A-Za-z0-9_.-]','_')
        $safeWorkflow=([string]$workflow.workflowId -replace '[^A-Za-z0-9_.-]','_')
        $final=Join-Path $exportRoot ("Dynomax_{0}_{1}_{2}_{3}.zip" -f $safeProject,$safeWorkflow,[DateTime]::UtcNow.ToString('yyyyMMddHHmmss'),$overall)
        $building=$final+'.building.zip'
        [void](New-DynomaxStandardZip -SourceDirectory $stagingRoot -DestinationPath $building)
        if(-not(Test-Path $building) -or (Get-Item $building).Length -le 0){throw 'Result ZIP build failed.'}
        Move-Item -LiteralPath $building -Destination $final -Force
        $resultZipPath=$final
        if(-not $SuppressClipboard -and [bool](Get-DynomaxPropertyValue -Object $config.execution -Name 'copyResultZipToClipboard' -DefaultValue $true)){
            try{Set-DynomaxClipboardFile -Path $final;Write-Host ("Result ZIP copied to clipboard: {0}" -f $final) -ForegroundColor Green}catch{Write-Warning $_.Exception.Message}
        }
        Write-Host ("Result ZIP: {0}" -f $final) -ForegroundColor Cyan
    }
        try{Remove-Item -LiteralPath $stagingRoot -Recurse -Force -ErrorAction Stop}catch{Write-Warning ("Export staging cleanup failed: {0}" -f $_.Exception.Message)}
        $finalizationStep='Completed'
        $finalizationStatus='Completed'
    }
    catch{
        $finalizationStatus='Failed'
        $finalizationFailureCode='CORE_FINALIZATION_FAILED'
        $finalizationFailureMessage=ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_
        Write-Warning ("Dynomax Result finalization failed after logical status '{0}': {1}" -f $logicalStatus,$finalizationFailureMessage)

        # A nonessential export/copy failure must not erase a completed logical Run. Rebuild one
        # compact, standard Result package from the authoritative SQL records. This recovery path
        # deliberately excludes raw browser/context/log files and therefore remains bounded.
        try{
            $normalFinalizationFailedStep=$finalizationStep
            Set-DynomaxFinalizationStep -Step 'Recovery.PrepareStaging'
            $recoveryExportRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.exports
            Ensure-DynomaxDirectory -Path $recoveryExportRoot|Out-Null
            $recoveryStaging=Join-Path $recoveryExportRoot ('.recovery\'+[string]$runId)
            if(Test-Path -LiteralPath $recoveryStaging){Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue}
            Ensure-DynomaxDirectory -Path $recoveryStaging|Out-Null

            Set-DynomaxFinalizationStep -Step 'Recovery.ExportRunSummary'
            [void](Export-DynomaxRunSummary -SqlConfig $sqlConfig -RunId $runId -OutputDirectory $recoveryStaging)
            Set-DynomaxFinalizationStep -Step 'Recovery.CopyDefinitions'
            $recoveryDefinitions=Ensure-DynomaxDirectory -Path (Join-Path $recoveryStaging 'Definitions')
            $recoveryProject=Ensure-DynomaxDirectory -Path (Join-Path $recoveryDefinitions 'Project')
            $recoveryWorkflow=Ensure-DynomaxDirectory -Path (Join-Path $recoveryDefinitions 'Workflow')
            Copy-Item -LiteralPath $projectConfigPath -Destination (Join-Path $recoveryProject 'project.json') -Force
            Copy-Item -LiteralPath $workflowPath -Destination (Join-Path $recoveryWorkflow 'workflow.json') -Force
            Write-DynomaxJson -Value ([ordered]@{
                schemaVersion=1
                failureCode='CORE_FINALIZATION_RECOVERED'
                failureMessage=$finalizationFailureMessage
                logicalStatus=$logicalStatus
                normalFinalizationStatus='Failed'
                normalFinalizationFailedStep=$normalFinalizationFailedStep
                recoveryStatus='Completed'
                runId=[string]$runId
                recordedAtUtc=[DateTime]::UtcNow.ToString('o')
            }) -Path (Join-Path $recoveryStaging 'FinalizationRecovery.json')
            $recoveryCleanup=[ordered]@{
                requested=$true
                attempted=$false
                succeeded=$false
                path=$runDirectory
                reason='Contained Worker cleanup runs after the recovered Result package is imported.'
                verifiedAtUtc=[DateTime]::UtcNow.ToString('o')
            }
            Write-DynomaxJson -Value $recoveryCleanup -Path (Join-Path $recoveryStaging 'TemporaryWorkspaceCleanup.json')
            Set-DynomaxFinalizationStep -Step 'Recovery.WriteExportManifest'
            [void](Write-DynomaxExportManifest -ExportDirectory $recoveryStaging -RunId $runId -FrameworkVersion ([string]$config.frameworkVersion) -TemporaryCleanup $recoveryCleanup)

            $safeProject=([string]$workflow.projectKey -replace '[^A-Za-z0-9_.-]','_')
            $safeWorkflow=([string]$workflow.workflowId -replace '[^A-Za-z0-9_.-]','_')
            Set-DynomaxFinalizationStep -Step 'Recovery.BuildResultZip'
            $recoveryFinal=Join-Path $recoveryExportRoot ("Dynomax_{0}_{1}_{2}_{3}_RECOVERED.zip" -f $safeProject,$safeWorkflow,[DateTime]::UtcNow.ToString('yyyyMMddHHmmss'),$logicalStatus)
            $recoveryBuilding=$recoveryFinal+'.building.zip'
            [void](New-DynomaxStandardZip -SourceDirectory $recoveryStaging -DestinationPath $recoveryBuilding)
            if(-not(Test-Path -LiteralPath $recoveryBuilding -PathType Leaf) -or (Get-Item -LiteralPath $recoveryBuilding).Length -le 0){throw 'Recovered Result ZIP build failed.'}
            Move-Item -LiteralPath $recoveryBuilding -Destination $recoveryFinal -Force
            $resultZipPath=$recoveryFinal
            $finalizationStep='Recovery.Completed'
            $finalizationStatus='Recovered'
            $finalizationFailureCode='CORE_FINALIZATION_RECOVERED'
            $overall=$logicalStatus
            Remove-Item -LiteralPath $recoveryStaging -Recurse -Force -ErrorAction SilentlyContinue
            Write-Warning 'Dynomax produced a compact recovered Result package after normal finalization failed.'
        }
        catch{
            $recoveryFailedStep=$finalizationStep
            $recoveryFailureMessage=ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_
            $finalizationStatus='Failed'
            $finalizationStep='Recovery.Failed'
            $overall='ERROR'
            $finalizationFailureMessage=("{0} Recovery also failed: {1}" -f $finalizationFailureMessage,$recoveryFailureMessage)
            if($finalizationFailureMessage.Length -gt 2000){$finalizationFailureMessage=$finalizationFailureMessage.Substring(0,2000)}

            # Last-resort metadata-only evidence. The Worker recognizes this state and replaces it
            # with a standard agent-readable diagnostic Result before durable import.
            try{
                Set-DynomaxFinalizationStep -Step 'Fallback.PrepareStaging'
                $fallbackExportRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.exports
                Ensure-DynomaxDirectory -Path $fallbackExportRoot|Out-Null
                $fallbackStaging=Join-Path $fallbackExportRoot ('.finalization-failure\'+[string]$runId)
                if(Test-Path -LiteralPath $fallbackStaging){Remove-Item -LiteralPath $fallbackStaging -Recurse -Force -ErrorAction SilentlyContinue}
                Ensure-DynomaxDirectory -Path $fallbackStaging|Out-Null
                Write-DynomaxJson -Value ([ordered]@{
                    schemaVersion=1
                    failureCode='CORE_FINALIZATION_FAILED'
                    failureMessage=$finalizationFailureMessage
                    logicalStatus=$logicalStatus
                    finalizationStatus=$finalizationStatus
                    normalFinalizationFailedStep=$normalFinalizationFailedStep
                    recoveryFailedStep=$recoveryFailedStep
                    runId=[string]$runId
                    recordedAtUtc=[DateTime]::UtcNow.ToString('o')
                }) -Path (Join-Path $fallbackStaging 'FinalizationFailure.json')
                # Never copy runtime context, secrets, raw console output, project configuration,
                # or Workflow inputs into the metadata-only fallback package.
                foreach($diagnosticPath in @((Join-Path $runDirectory 'preflight.json'),(Join-Path $runDirectory 'control-flow-state.json'),(Join-Path $runDirectory 'orchestration-performance.jsonl'))){
                    if(Test-Path -LiteralPath $diagnosticPath -PathType Leaf){Copy-Item -LiteralPath $diagnosticPath -Destination (Join-Path $fallbackStaging ([System.IO.Path]::GetFileName($diagnosticPath))) -Force}
                }
                $safeProject=([string]$workflow.projectKey -replace '[^A-Za-z0-9_.-]','_')
                $safeWorkflow=([string]$workflow.workflowId -replace '[^A-Za-z0-9_.-]','_')
                Set-DynomaxFinalizationStep -Step 'Fallback.BuildResultZip'
                $fallbackFinal=Join-Path $fallbackExportRoot ("Dynomax_{0}_{1}_{2}_CORE_FINALIZATION_FAILED.zip" -f $safeProject,$safeWorkflow,[DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))
                $fallbackBuilding=$fallbackFinal+'.building.zip'
                [void](New-DynomaxStandardZip -SourceDirectory $fallbackStaging -DestinationPath $fallbackBuilding)
                if((Test-Path -LiteralPath $fallbackBuilding -PathType Leaf) -and (Get-Item -LiteralPath $fallbackBuilding).Length -gt 0){
                    Move-Item -LiteralPath $fallbackBuilding -Destination $fallbackFinal -Force
                    $resultZipPath=$fallbackFinal
                }
                Remove-Item -LiteralPath $fallbackStaging -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch{
                Write-Warning ("Fallback finalization evidence could not be produced: {0}" -f (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_))
            }
        }
    }
    finally{
        if($RunContractPath){
            $contractStatus=$(if($finalizationStatus -in @('Completed','Recovered')){$logicalStatus}else{'ERROR'})
            try{
                Write-DynomaxRunContractAtomic -Path $RunContractPath -RunId $runId -ProjectKey ([string]$workflow.projectKey) -WorkflowId ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -Status $contractStatus -LogicalStatus $logicalStatus -FinalizationStatus $finalizationStatus -FinalizationStep $finalizationStep -ResultZipPath $resultZipPath -FailureCode $finalizationFailureCode -FailureMessage $finalizationFailureMessage
            }catch{Write-Warning ("Terminal run-contract checkpoint failed: {0}" -f (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_))}
        }
    }
}

Write-Host ("Dynomax Run ID: {0}" -f $runId) -ForegroundColor Cyan
Write-Host ("Overall Status: {0}" -f $overall) -ForegroundColor $(if($overall -eq 'PASS'){'Green'}else{'Red'})
if($overall -ne 'PASS'){
    try{$problem=Get-DynomaxFirstProblem -SqlConfig $sqlConfig -RunId $runId;if($problem){Write-Host ("First problem: step {0}, {1}, {2}: {3}" -f $problem.StepOrder,$problem.ActionKey,$problem.Status,$problem.Message) -ForegroundColor Yellow}}catch{}
}
if($overall -eq 'PASS'){exit 0}else{exit 1}
