[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkflowDirectory,
    [string]$DynomaxConfigPath,
    [string]$RuntimeProjectFolder,
    [string]$ContextSeedPath,
    [string]$RunContractPath,
    [string]$InteractionCheckpointPath,
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
. (Join-Path $root 'Core\Execution\Dynomax.RuntimeContext.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Parallel.ps1')


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
    return $relative -match '(?i)^(preflight\.json|core-diagnostics\.jsonl|control-flow-state\.json|orchestration-performance\.jsonl|execution-attempts\.jsonl|parallel-execution\.jsonl|robot-console\.log|runtime-control-flow\.json|parallel/[^/]+/branch-[^/]+/branch-result\.json|discovery-[^/]+\.json)$'
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
$context=[ordered]@{schemaVersion=4;secretKeys=@();sensitiveKeys=@();values=[ordered]@{workflowBlocked=$false;projectKey=[string]$workflow.projectKey;environment=[string]$workflow.environment;workflowVersionId=[string]$workflowVersionId;workflowVersion=[int]$workflowVersionRecord.VersionNumber};runDataPool=[ordered]@{schemaVersion=1;steps=[ordered]@{}};stepInputs=[ordered]@{};runtimeValues=[ordered]@{};runtimePolicy=[ordered]@{};continuation=$null}
$interactionResume=$null
if($ContextSeedPath){
    $resolvedSeedPath=[System.IO.Path]::GetFullPath($ContextSeedPath)
    if(-not(Test-Path -LiteralPath $resolvedSeedPath -PathType Leaf)){throw "Context seed does not exist: $resolvedSeedPath"}
    $seed=Read-DynomaxJson -Path $resolvedSeedPath
    $seedSchema=[int](Get-DynomaxPropertyValue -Object $seed -Name 'schemaVersion' -DefaultValue 0); if($seedSchema -notin @(1,2,3,4)){throw 'Context seed schemaVersion must be 1, 2, 3 or 4.'}
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
        if($seedSchema -lt 3 -or $seedContinuation -isnot [System.Management.Automation.PSCustomObject]){throw 'Continuation context requires context seed schemaVersion 3 or later and a JSON object.'}
        $context.continuation=$seedContinuation
    }
    $seedInteractionResume=Get-DynomaxPropertyValue -Object $seed -Name 'interactionResume' -DefaultValue $null
    if($null -ne $seedInteractionResume){
        if($seedSchema -ne 4 -or $seedInteractionResume -isnot [System.Management.Automation.PSCustomObject]){throw 'Interaction resume requires context seed schemaVersion 4 and a JSON object.'}
        $interactionResume=$seedInteractionResume
    }
}
Write-DynomaxJson -Value $context -Path $contextPath
if($null -ne $interactionResume){
    $resumeRunId=[Guid]::Empty
    if(-not[Guid]::TryParse([string](Get-DynomaxPropertyValue -Object $interactionResume -Name 'coreRunId' -DefaultValue ''),[ref]$resumeRunId) -or $resumeRunId -eq [Guid]::Empty){throw 'Interaction resume is missing the existing Core Run identity.'}
    $runId=$resumeRunId
    Resume-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -WorkingDirectory $runDirectory
    Write-DynomaxCoreDiagnostic -Level 'Information' -Stage 'TestRunResumed' -Message 'Existing internal Core TestRun resumed in-place for User Interaction continuation.' -CoreRunId $runId
}else{
    $runId=New-DynomaxTestRun -SqlConfig $sqlConfig -ProjectKey ([string]$workflow.projectKey) -WorkflowKey ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -EnvironmentKey ([string]$workflow.environment) -WorkingDirectory $runDirectory -PackageHash $packageHash
    Write-DynomaxCoreDiagnostic -Level 'Information' -Stage 'TestRunCreated' -Message 'Internal Core TestRun was created.' -CoreRunId $runId
}
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

function Invoke-DynomaxStepSequence {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Sequence)
    $parallelRegionNodeIds=Get-DynomaxParallelForkRegionNodeIds -Workflow $workflow
    if($null -eq $parallelRegionNodeIds){$parallelRegionNodeIds=New-Object 'System.Collections.Generic.HashSet[string]'}
    $parallelConsumedOrders=New-Object 'System.Collections.Generic.HashSet[int]'
    $index=0
    while($index -lt $Sequence.Count){
        if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
            $parallelExecution=Invoke-DynomaxPendingParallelFork -Workflow $workflow -Sequence $Sequence -DynomaxRoot $root -ProjectFolder $projectFolder -WorkflowDirectory $WorkflowDirectory -RunId $runId -RunDirectory $runDirectory -ContextPath $contextPath -PowerShellPath $powerShell -PythonPath $python -SqlConfig $sqlConfig -PersistedContextCache $directPersistedContextCache -TimeoutSeconds $timeout -HeartbeatSeconds $processHeartbeatSeconds
            if([bool](Get-DynomaxPropertyValue -Object $parallelExecution -Name 'Executed' -DefaultValue $false)){
                foreach($consumedOrder in @((Get-DynomaxPropertyValue -Object $parallelExecution -Name 'ConsumedStepOrders' -DefaultValue @()))){[void]$parallelConsumedOrders.Add([int]$consumedOrder)}
                if([bool](Get-DynomaxPropertyValue -Object $parallelExecution -Name 'Terminal' -DefaultValue $false)){
                    [void](Add-DynomaxMissingControlFlowActionRuns -SqlConfig $sqlConfig -RunId $runId -Steps $Sequence -ContextPath $contextPath)
                    break
                }
            }
        }

        $step=$Sequence[$index]
        $stepOrder=[int](Get-DynomaxPropertyValue -Object $step -Name 'order' -DefaultValue 0)
        if($parallelConsumedOrders.Contains($stepOrder)){$index++;continue}
        $logicalNodeId=[string](Get-DynomaxPropertyValue -Object $step -Name 'workflowNodeId' -DefaultValue ([string]$step.stepId))
        $engine=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxEngine' -DefaultValue '')

        if($parallelRegionNodeIds.Contains($logicalNodeId)){
            $disposition='RUN'
            if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                $decision=Get-DynomaxControlFlowDecision -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory -NodeId $logicalNodeId
                $disposition=[string]$decision.Disposition
            }
            if($disposition -eq 'PARALLEL_WAIT'){
                # An active parallel Fork should have been consumed at the top of this loop.
                # Reaching the physical branch Action here indicates an inconsistent state/plan.
                throw "Parallel Fork scheduling did not consume branch Action '$logicalNodeId'."
            }
            if($disposition -eq 'SKIP_FINAL'){
                $versionId=[Guid][string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue [Guid]::Empty)
                Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $runId -StepOrder $stepOrder -ActionKey ([string]$step.actionId) -ActionVersionId $versionId -Status 'SKIPPED' -Message 'Physical Action slot was not selected by bounded parallel Fork execution.'
                $index++
                continue
            }
            if($disposition -eq 'DEFER'){$index++;continue}
            throw "Parallel branch Action '$logicalNodeId' escaped isolated branch scheduling with disposition '$disposition'."
        }

        if($engine -eq 'RobotBrowser'){
            $block=[System.Collections.Generic.List[object]]::new()
            while($index -lt $Sequence.Count){
                $candidate=$Sequence[$index]
                $candidateOrder=[int](Get-DynomaxPropertyValue -Object $candidate -Name 'order' -DefaultValue 0)
                if($parallelConsumedOrders.Contains($candidateOrder)){$index++;continue}
                $candidateEngine=[string](Get-DynomaxPropertyValue -Object $candidate -Name 'DynomaxEngine' -DefaultValue '')
                if($candidateEngine -ne 'RobotBrowser'){break}
                $candidateNodeId=[string](Get-DynomaxPropertyValue -Object $candidate -Name 'workflowNodeId' -DefaultValue ([string]$candidate.stepId))
                if($parallelRegionNodeIds.Contains($candidateNodeId)){break}
                $block.Add($candidate);$index++
            }
            if($block.Count -eq 0){continue}
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
                        [void](Add-DynomaxMissingControlFlowActionRuns -SqlConfig $sqlConfig -RunId $runId -Steps $Sequence -ContextPath $contextPath)
                        $index=$Sequence.Count
                    }
                }
            }
        }
        elseif($engine -eq 'PowerShell'){
            $disposition='RUN'
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
                        }catch{$stepFailure=$_}
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
                        $completionState=Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory -NodeId $logicalNodeId -DeferStateWrite
                        [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory -State $completionState)
                    }
                }
            }
            elseif($disposition -eq 'SKIP_FINAL'){
                $versionId=[Guid][string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue [Guid]::Empty)
                Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $runId -StepOrder $stepOrder -ActionKey ([string]$step.actionId) -ActionVersionId $versionId -Status 'SKIPPED' -Message 'Action was not selected by Workflow control flow.'
            }
            elseif($disposition -eq 'PARALLEL_WAIT'){
                throw "Parallel Fork scheduling reached unexpected non-branch Action '$logicalNodeId'."
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
    $parallelRegions=Get-DynomaxParallelForkRegionNodeIds -Workflow $workflow
    if($parallelRegions.Count -gt 0){return $false}
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
            if($null -ne $interactionResume){
                $resumeState=Get-DynomaxPropertyValue -Object $interactionResume -Name 'controlFlowState' -DefaultValue $null
                $resumeNodeId=[string](Get-DynomaxPropertyValue -Object $interactionResume -Name 'nodeId' -DefaultValue '')
                $resumeResponseSchema=Get-DynomaxPropertyValue -Object $interactionResume -Name 'responseSchema' -DefaultValue $null
                $resumeResponseValues=Get-DynomaxPropertyValue -Object $interactionResume -Name 'responseValues' -DefaultValue $null
                if($null -eq $resumeState -or -not $resumeNodeId -or $null -eq $resumeResponseSchema -or $null -eq $resumeResponseValues){throw 'Interaction resume is missing persisted control-flow state, checkpoint node identity, response schema or response values.'}
                Write-DynomaxJson -Value $resumeState -Path (Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory)
                $interactionResponseStep=Set-DynomaxInteractionResponseOutputs -ContextPath $contextPath -NodeId $resumeNodeId -ResponseSchema $resumeResponseSchema -ResponseValues $resumeResponseValues
                Set-DynomaxRunDataPoolStepInSql -SqlConfig $sqlConfig -RunId $runId -StepId $resumeNodeId -Step $interactionResponseStep -PersistedContextCache $directPersistedContextCache
                [void](Resume-DynomaxControlFlowInteraction -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory -NodeId $resumeNodeId)
            }else{
                [void](Initialize-DynomaxControlFlowState -Workflow $workflow -ContextPath $contextPath -RunDirectory $runDirectory)
            }
            Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory
        }
        $alwaysRunCleanup=[bool](Get-DynomaxPropertyValue -Object $workflow -Name 'alwaysRunCleanup' -DefaultValue $true)
        $hasUserInteraction=(Test-DynomaxControlFlowEnabled -Workflow $workflow) -and @($workflow.controlFlow.nodes|Where-Object{[string]$_.type -eq 'UserInteraction'}).Count -gt 0
        $preserveCleanupBrowserSession=$alwaysRunCleanup -and -not $hasUserInteraction -and (Test-DynomaxPreservedCleanupBrowserSessionEligible -MainSteps $mainSteps -CleanupSteps $cleanupSteps)
        if($preserveCleanupBrowserSession){
            try{Invoke-DynomaxPreservedBrowserMainAndCleanup -MainSteps $mainSteps -CleanupSteps $cleanupSteps}catch{$executionException=$_;Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Main' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId}
        }
        else{
            try{Invoke-DynomaxStepSequence -Sequence $mainSteps}catch{$executionException=$_;Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Main' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId}
            $waitingAfterMain=$false
            if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
                $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
                if(Test-Path -LiteralPath $statePath -PathType Leaf){
                    $afterMainState=Read-DynomaxJson -Path $statePath
                    $waitingAfterMain=[bool](Get-DynomaxPropertyValue -Object $afterMainState -Name 'waitingForUser' -DefaultValue $false)
                }
            }
            if(-not $waitingAfterMain -and $alwaysRunCleanup -and $cleanupSteps.Count -gt 0){
                try{Invoke-DynomaxStepSequence -Sequence $cleanupSteps}catch{$cleanupException=$_;Write-DynomaxCoreDiagnostic -Level 'Error' -Stage 'Execution.Cleanup' -Message (ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_) -CoreRunId $runId}
            }
        }
        $overall=Get-DynomaxOverallStatus -SqlConfig $sqlConfig -RunId $runId
        if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
            $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
            if(Test-Path -LiteralPath $statePath -PathType Leaf){
                $controlState=Read-DynomaxJson -Path $statePath
                $terminalStatus=[string](Get-DynomaxPropertyValue -Object $controlState -Name 'terminalStatus' -DefaultValue '')
                $waitingForUser=[bool](Get-DynomaxPropertyValue -Object $controlState -Name 'waitingForUser' -DefaultValue $false)
                if($waitingForUser -and -not $executionException){$overall='WAITING_FOR_USER'}
                elseif($terminalStatus -eq 'FAIL'){$overall='FAIL'}
                elseif($terminalStatus -eq 'PASS' -and -not $executionException){$overall='PASS'}
                elseif(-not $terminalStatus -and -not $executionException){$overall='ERROR';$executionException=[pscustomobject]@{Exception=[System.InvalidOperationException]::new('Workflow control flow did not reach a terminal node or interaction checkpoint.')}}
            }
        }
        if($cleanupException -and $overall -eq 'PASS'){$overall='CLEANUP_FAILED'}
        if($executionException -and $overall -eq 'PASS'){$overall='ERROR'}
        $message="Workflow '$($workflow.displayName)' completed with status $overall."
        if($executionException){$message += " Execution error: $($executionException.Exception.Message)"}
        if($cleanupException){$message += " Cleanup error: $($cleanupException.Exception.Message)"}
        if($overall -eq 'WAITING_FOR_USER'){
            Set-DynomaxTestRunWaitingForUser -SqlConfig $sqlConfig -RunId $runId -Summary 'Workflow is waiting for an authorized User Interaction response.'
        }else{
            Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary $message
        }
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
    if($logicalStatus -eq 'WAITING_FOR_USER'){
        try{
            $waitingContext=Read-DynomaxJson -Path $contextPath
            Set-DynomaxContextValuesInSql -SqlConfig $sqlConfig -RunId $runId -Context $waitingContext -PersistedContextCache $directPersistedContextCache
            Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $runId -RunDirectory $runDirectory
            $waitingStatePath=Get-DynomaxControlFlowStatePath -RunDirectory $runDirectory
            $waitingState=Read-DynomaxJson -Path $waitingStatePath
            $checkpoint=Get-DynomaxPropertyValue -Object $waitingState -Name 'interactionCheckpoint' -DefaultValue $null
            if($null -eq $checkpoint){throw 'WaitingForUser control-flow state has no interaction checkpoint descriptor.'}
            $checkpointPayload=[ordered]@{
                schemaVersion=1
                coreRunId=[string]$runId
                nodeId=[string]$checkpoint.nodeId
                pageKey=[string]$checkpoint.pageKey
                responseSchema=$checkpoint.responseSchema
                checkpointContractSha256=[string]$checkpoint.checkpointContractSha256
                nextNodeId=[string]$checkpoint.nextNodeId
                nextEdgeId=$(if($checkpoint.nextEdgeId){[string]$checkpoint.nextEdgeId}else{$null})
                controlFlowState=$waitingState
                persistedAtUtc=[DateTime]::UtcNow.ToString('o')
            }
            $checkpointPath=Join-Path $runDirectory 'interaction-checkpoint.json'
            Write-DynomaxJson -Value $checkpointPayload -Path $checkpointPath
            if(-not [string]::IsNullOrWhiteSpace([string]$InteractionCheckpointPath)){
                $checkpointHandoffPath=[System.IO.Path]::GetFullPath($InteractionCheckpointPath)
                if(-not [string]::Equals($checkpointHandoffPath,$checkpointPath,[System.StringComparison]::OrdinalIgnoreCase)){
                    Write-DynomaxJson -Value $checkpointPayload -Path $checkpointHandoffPath
                }
            }
            if($RunContractPath){
                Write-DynomaxRunContractAtomic -Path $RunContractPath -RunId $runId -ProjectKey ([string]$workflow.projectKey) -WorkflowId ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -Status 'WAITING_FOR_USER' -LogicalStatus 'WAITING_FOR_USER' -FinalizationStatus 'DeferredForUser' -FinalizationStep 'InteractionCheckpointPersisted' -ResultZipPath $null -FailureCode $null -FailureMessage $null
            }
        }catch{
            $waitingFailure=ConvertTo-DynomaxBoundedDiagnosticMessage -ErrorRecord $_
            $logicalStatus='ERROR';$overall='ERROR'
            try{Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status 'ERROR' -Summary ('Interaction checkpoint persistence failed: '+$waitingFailure)}catch{}
            if($RunContractPath){
                try{Write-DynomaxRunContractAtomic -Path $RunContractPath -RunId $runId -ProjectKey ([string]$workflow.projectKey) -WorkflowId ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -Status 'ERROR' -LogicalStatus 'ERROR' -FinalizationStatus 'Failed' -FinalizationStep 'InteractionCheckpointPersistence' -ResultZipPath $null -FailureCode 'CORE_INTERACTION_CHECKPOINT_FAILED' -FailureMessage $waitingFailure}catch{}
            }
        }
    }else{
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
        'parallel-execution.jsonl',
        'robot-console.log'
    )
    if($logicalStatus -ne 'PASS'){$rootEvidenceNames+=@('generated-workflow.robot')}
    foreach($name in $rootEvidenceNames){
        $source=Join-Path $runDirectory $name
        if((Test-Path -LiteralPath $source -PathType Leaf) -and ((Get-Item -LiteralPath $source).Length -gt 0)){
            Copy-Item -LiteralPath $source -Destination (Join-Path $testEvidence $name) -Force
        }
    }
    $parallelEvidence=Join-Path $runDirectory 'parallel'
    if(Test-Path -LiteralPath $parallelEvidence -PathType Container){
        $parallelTestEvidence=Ensure-DynomaxDirectory -Path (Join-Path $testEvidence 'Parallel')
        foreach($branchResult in Get-ChildItem -LiteralPath $parallelEvidence -Filter 'branch-result.json' -File -Recurse -ErrorAction SilentlyContinue){
            $relativeBranchResult=(Get-DynomaxRelativePath -BasePath $parallelEvidence -TargetPath $branchResult.FullName) -replace '\\','/'
            $destination=Join-Path $parallelTestEvidence ($relativeBranchResult -replace '/', [System.IO.Path]::DirectorySeparatorChar)
            [void](Ensure-DynomaxDirectory -Path (Split-Path -Parent $destination))
            Copy-Item -LiteralPath $branchResult.FullName -Destination $destination -Force
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
                foreach($diagnosticPath in @((Join-Path $runDirectory 'preflight.json'),(Join-Path $runDirectory 'control-flow-state.json'),(Join-Path $runDirectory 'orchestration-performance.jsonl'),(Join-Path $runDirectory 'parallel-execution.jsonl'))){
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
}

Write-Host ("Dynomax Run ID: {0}" -f $runId) -ForegroundColor Cyan
Write-Host ("Overall Status: {0}" -f $overall) -ForegroundColor $(if($overall -in @('PASS','WAITING_FOR_USER')){'Green'}else{'Red'})
if($overall -notin @('PASS','WAITING_FOR_USER')){
    try{$problem=Get-DynomaxFirstProblem -SqlConfig $sqlConfig -RunId $runId;if($problem){Write-Host ("First problem: step {0}, {1}, {2}: {3}" -f $problem.StepOrder,$problem.ActionKey,$problem.Status,$problem.Message) -ForegroundColor Yellow}}catch{}
}
if($overall -in @('PASS','WAITING_FOR_USER')){exit 0}else{exit 1}
