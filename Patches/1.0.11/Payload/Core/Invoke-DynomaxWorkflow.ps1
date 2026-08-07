[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkflowDirectory,
    [string]$DynomaxConfigPath,
    [string]$RuntimeProjectFolder,
    [string]$ContextSeedPath,
    [string]$RunContractPath,
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
. (Join-Path $root 'Core\Execution\Dynomax.Workflow.ps1')

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
$context=[ordered]@{schemaVersion=1;secretKeys=@();values=[ordered]@{workflowBlocked=$false;projectKey=[string]$workflow.projectKey;environment=[string]$workflow.environment;workflowVersionId=[string]$workflowVersionId;workflowVersion=[int]$workflowVersionRecord.VersionNumber}}
if($ContextSeedPath){
    $resolvedSeedPath=[System.IO.Path]::GetFullPath($ContextSeedPath)
    if(-not(Test-Path -LiteralPath $resolvedSeedPath -PathType Leaf)){throw "Context seed does not exist: $resolvedSeedPath"}
    $seed=Read-DynomaxJson -Path $resolvedSeedPath
    if([int](Get-DynomaxPropertyValue -Object $seed -Name 'schemaVersion' -DefaultValue 0) -ne 1){throw 'Context seed schemaVersion must be 1.'}
    $seedValues=Get-DynomaxPropertyValue -Object $seed -Name 'values' -DefaultValue $null
    if($null -eq $seedValues){throw 'Context seed values are required.'}
    $seedSecretKeys=@(Get-DynomaxPropertyValue -Object $seed -Name 'secretKeys' -DefaultValue @())
    $context.secretKeys=@($seedSecretKeys|ForEach-Object{[string]$_}|Where-Object{-not [string]::IsNullOrWhiteSpace($_)}|Sort-Object -Unique)
    foreach($property in @($seedValues.PSObject.Properties)){
        if([string]::IsNullOrWhiteSpace([string]$property.Name)){throw 'Context seed contains an empty key.'}
        $context.values[[string]$property.Name]=$property.Value
    }
}
Write-DynomaxJson -Value $context -Path $contextPath
$runId=New-DynomaxTestRun -SqlConfig $sqlConfig -ProjectKey ([string]$workflow.projectKey) -WorkflowKey ([string]$workflow.workflowId) -WorkflowVersionId $workflowVersionId -EnvironmentKey ([string]$workflow.environment) -WorkingDirectory $runDirectory -PackageHash $packageHash
$context.values.runId=[string]$runId
Write-DynomaxJson -Value $context -Path $contextPath

$allSteps=@($workflow.steps|Sort-Object order)
$stepPlans=@{}
$preflightException=$null
$preflightSummary=[ordered]@{status='PASS';classification=$null;stepOrder=$null;actionId=$null;message='Exact workflow and action-version preflight passed.';checkedAtUtc=[DateTime]::UtcNow.ToString('o')}
try{
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
    $classification='ERROR'
    $stepOrder=if($_.Exception.Data.Contains('DynomaxStepOrder')){[int]$_.Exception.Data['DynomaxStepOrder']}else{0}
    $actionKey=if($_.Exception.Data.Contains('DynomaxActionKey')){[string]$_.Exception.Data['DynomaxActionKey']}else{'workflow.preflight'}
    if($_.Exception.Data.Contains('DynomaxClassification')){$classification=[string]$_.Exception.Data['DynomaxClassification']}
    $preflightSummary.status='FAILED'
    $preflightSummary.classification=$classification
    $preflightSummary.stepOrder=$stepOrder
    $preflightSummary.actionId=$actionKey
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
    param([Parameter(Mandatory)][object[]]$Sequence)
    $index=0
    while($index -lt $Sequence.Count){
        $step=$Sequence[$index]
        $engine=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxEngine' -DefaultValue '')
        if($engine -eq 'RobotBrowser'){
            $block=New-Object System.Collections.Generic.List[object]
            while($index -lt $Sequence.Count){
                $candidate=$Sequence[$index]
                $candidateEngine=[string](Get-DynomaxPropertyValue -Object $candidate -Name 'DynomaxEngine' -DefaultValue '')
                if($candidateEngine -ne 'RobotBrowser'){break}
                $block.Add($candidate);$index++
            }
            $process=Invoke-DynomaxRobotBlock -DynomaxRoot $root -ProjectFolder $projectFolder -ProjectConfig $projectConfig -Workflow $workflow -Steps $block.ToArray() -RunId $runId -RunDirectory $runDirectory -ContextPath $contextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -PythonPath $python -TimeoutSeconds $timeout -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds
            $outputXml=Join-Path $runDirectory 'robot-result\output.xml'
            if(-not(Test-Path $outputXml)){throw "Robot did not produce output.xml. Exit code: $($process.ExitCode). Error: $($process.StandardError)"}
        }
        elseif($engine -eq 'PowerShell'){
            [void](Invoke-DynomaxPowerShellAction -DynomaxRoot $root -ProjectFolder $projectFolder -RunId $runId -Step $step -ContextPath $contextPath -RunDirectory $runDirectory -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -SqlConfig $sqlConfig -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds)
            $index++
        }
        else{throw "Unsupported action engine '$engine' for '$($step.actionId)'."}
    }
}

$mainSteps=@($allSteps|Where-Object{-not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)})
$cleanupSteps=@($allSteps|Where-Object{[bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)}|Sort-Object order -Descending)
$overall='ERROR'
$executionException=$null
$cleanupException=$null
$resultZipPath=$null

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

        try{Invoke-DynomaxStepSequence -Sequence $mainSteps}catch{$executionException=$_}
        $alwaysRunCleanup=[bool](Get-DynomaxPropertyValue -Object $workflow -Name 'alwaysRunCleanup' -DefaultValue $true)
        if($alwaysRunCleanup -and $cleanupSteps.Count -gt 0){
            try{Invoke-DynomaxStepSequence -Sequence $cleanupSteps}catch{$cleanupException=$_}
        }
        $overall=Get-DynomaxOverallStatus -SqlConfig $sqlConfig -RunId $runId
        if($cleanupException -and $overall -eq 'PASS'){$overall='CLEANUP_FAILED'}
        if($executionException -and $overall -eq 'PASS'){$overall='ERROR'}
        $message="Workflow '$($workflow.displayName)' completed with status $overall."
        if($executionException){$message += " Execution error: $($executionException.Exception.Message)"}
        if($cleanupException){$message += " Cleanup error: $($cleanupException.Exception.Message)"}
        Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary $message
    }
}
finally{
    if(Test-Path $contextPath){try{$finalContext=Read-DynomaxJson -Path $contextPath;Set-DynomaxContextValuesInSql -SqlConfig $sqlConfig -RunId $runId -Context $finalContext}catch{Write-Warning $_.Exception.Message}}

    $artifactIngestionSucceeded=$true
    $max=[long]$config.execution.maximumSqlArtifactBytes
    $evidencePatterns='\.(xml|html?|log|png|jpe?g|json|md|txt)$'
    Get-ChildItem -LiteralPath $runDirectory -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object{$_.Name -ne 'context.json' -and $_.Extension -match $evidencePatterns} |
        ForEach-Object{
            try{[void](Add-DynomaxArtifact -SqlConfig $sqlConfig -RunId $runId -ArtifactType 'RunEvidence' -Path $_.FullName -MaximumBytes $max)}
            catch{$artifactIngestionSucceeded=$false;Write-Warning ("Artifact ingestion failed for '{0}': {1}" -f $_.FullName,$_.Exception.Message)}
        }

    $exportRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.exports
    Ensure-DynomaxDirectory -Path $exportRoot|Out-Null
    $stagingRoot=Ensure-DynomaxDirectory -Path (Join-Path $exportRoot ('.staging\'+[string]$runId))
    if(Test-Path $stagingRoot){Get-ChildItem -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue|Remove-Item -Recurse -Force -ErrorAction SilentlyContinue}

    try{[void](Export-DynomaxRunSummary -SqlConfig $sqlConfig -RunId $runId -OutputDirectory $stagingRoot)}catch{$artifactIngestionSucceeded=$false;Write-Warning $_.Exception.Message}

    $projectExport=Join-Path $runDirectory 'project-export'
    if(Test-Path -LiteralPath $projectExport -PathType Container){
        Copy-Item -LiteralPath $projectExport -Destination (Join-Path $stagingRoot 'ProjectFindings') -Recurse -Force
    }

    $testEvidence=Ensure-DynomaxDirectory -Path (Join-Path $stagingRoot 'TestEvidence')
    $robotResult=Join-Path $runDirectory 'robot-result'
    if(Test-Path $robotResult){Copy-Item -LiteralPath $robotResult -Destination (Join-Path $testEvidence 'Robot') -Recurse -Force}
    foreach($file in Get-ChildItem -LiteralPath $runDirectory -File -ErrorAction SilentlyContinue | Where-Object{$_.Name -match '^(preflight\.json|robot-console\.log|generated-workflow\.robot|action-.*\.(json|log)|persist-.*\.(log|txt))$'}){
        Copy-Item -LiteralPath $file.FullName -Destination $testEvidence -Force
    }
    $screenshots=Join-Path $runDirectory 'screenshots'
    if(Test-Path $screenshots){Copy-Item -LiteralPath $screenshots -Destination (Join-Path $testEvidence 'Screenshots') -Recurse -Force}
    $attemptEvidence=Join-Path $runDirectory 'attempt-evidence'
    if(Test-Path $attemptEvidence){Copy-Item -LiteralPath $attemptEvidence -Destination (Join-Path $testEvidence 'Attempts') -Recurse -Force}

    $definitions=Ensure-DynomaxDirectory -Path (Join-Path $stagingRoot 'Definitions')
    $projectDefinitionDir=Ensure-DynomaxDirectory -Path (Join-Path $definitions 'Project')
    Copy-Item -LiteralPath $projectConfigPath -Destination (Join-Path $projectDefinitionDir 'project.json') -Force
    $workflowDefinitionDir=Ensure-DynomaxDirectory -Path (Join-Path $definitions 'Workflow')
    Copy-Item -LiteralPath $workflowPath -Destination (Join-Path $workflowDefinitionDir 'workflow.json') -Force
    $manifestActions=@()
    foreach($step in $allSteps){
        $planKey=[string][int]$step.order
        $requested=Get-DynomaxPropertyValue -Object $step -Name 'actionVersion' -DefaultValue $null
        if($stepPlans.ContainsKey($planKey)){
            $plan=$stepPlans[$planKey]
            $safe=([string]$step.actionId -replace '[^A-Za-z0-9_.-]','_')
            $actionDestination=Join-Path $definitions ("Actions\{0:D6}-{1}" -f [int]$step.order,$safe)
            Ensure-DynomaxDirectory -Path $actionDestination|Out-Null
            foreach($sourceFile in Get-ChildItem -LiteralPath $plan.Folder -File){Copy-Item -LiteralPath $sourceFile.FullName -Destination (Join-Path $actionDestination $sourceFile.Name) -Force}
            $manifestActions += [ordered]@{
                order=[int]$step.order
                actionId=[string]$step.actionId
                cleanup=[bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)
                requestedActionVersion=$(if($null -eq $plan.RequestedActionVersion){$null}else{[int]$plan.RequestedActionVersion})
                resolvedActionVersion=[int]$plan.ResolvedActionVersion
                actionVersionId=[string]$plan.ActionVersionId
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
        actions=$manifestActions
    }
    Write-DynomaxJson -Value $workflowManifest -Path (Join-Path $stagingRoot 'WorkflowManifest.json')

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

    [void](Write-DynomaxExportManifest -ExportDirectory $stagingRoot -RunId $runId -FrameworkVersion ([string]$config.frameworkVersion) -TemporaryCleanup $temporaryCleanup)

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
}

if($RunContractPath){
    $resolvedContractPath=[System.IO.Path]::GetFullPath($RunContractPath)
    $contractParent=Split-Path -Parent $resolvedContractPath
    if($contractParent){[System.IO.Directory]::CreateDirectory($contractParent)|Out-Null}
    $runContract=[ordered]@{
        schemaVersion=1
        runId=[string]$runId
        projectKey=[string]$workflow.projectKey
        workflowId=[string]$workflow.workflowId
        workflowVersionId=[string]$workflowVersionId
        status=[string]$overall
        resultZipPath=$(if($resultZipPath){[string]$resultZipPath}else{$null})
        completedAtUtc=[DateTime]::UtcNow.ToString('o')
    }
    Write-DynomaxJson -Value $runContract -Path $resolvedContractPath
}

Write-Host ("Dynomax Run ID: {0}" -f $runId) -ForegroundColor Cyan
Write-Host ("Overall Status: {0}" -f $overall) -ForegroundColor $(if($overall -eq 'PASS'){'Green'}else{'Red'})
if($overall -ne 'PASS'){
    try{$problem=Get-DynomaxFirstProblem -SqlConfig $sqlConfig -RunId $runId;if($problem){Write-Host ("First problem: step {0}, {1}, {2}: {3}" -f $problem.StepOrder,$problem.ActionKey,$problem.Status,$problem.Message) -ForegroundColor Yellow}}catch{}
}
if($overall -eq 'PASS'){exit 0}else{exit 1}
