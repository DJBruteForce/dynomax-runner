[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][string]$ProjectFolder,
    [Parameter(Mandatory)][string]$WorkflowDirectory,
    [Parameter(Mandatory)][string]$BranchWorkflowPath,
    [Parameter(Mandatory)][string]$BranchStepsPath,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][int]$BranchIndex,
    [int]$BranchAttempt=1,
    [Parameter(Mandatory)][string]$ResultPath,
    [Parameter(Mandatory)][string]$PythonPath,
    [Parameter(Mandatory)][string]$PowerShellPath,
    [int]$TimeoutSeconds=0,
    [int]$HeartbeatSeconds=15
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$startedAt=[DateTime]::UtcNow

. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Process.ps1')
. (Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $DynomaxRoot 'Core\Catalogue\Dynomax.Catalogue.ps1')
. (Join-Path $DynomaxRoot 'Core\Results\Dynomax.Results.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ExecutionPolicy.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ControlFlow.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Workflow.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.RuntimeContext.ps1')

$config=Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
$projectConfig=Read-DynomaxJson -Path (Join-Path $ProjectFolder 'Project-And-Config\project.json')
$workflow=Read-DynomaxJson -Path $BranchWorkflowPath
$sequence=@((Read-DynomaxJson -Path $BranchStepsPath)|Sort-Object order)
$persistedContextCache=@{}

function Invoke-DynomaxBranchStepSequence {
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
            $process=Invoke-DynomaxRobotBlock -DynomaxRoot $DynomaxRoot -ProjectFolder $ProjectFolder -ProjectConfig $projectConfig -Workflow $workflow -Steps $blockSteps -RunId $RunId -RunDirectory $RunDirectory -ContextPath $ContextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $PowerShellPath -PythonPath $PythonPath -TimeoutSeconds $TimeoutSeconds -StreamOutput:$false -ShowCommand:$false -HeartbeatSeconds $HeartbeatSeconds -RuntimeWorkflowPath $BranchWorkflowPath
            $outputXml=Join-Path $RunDirectory 'robot-result\output.xml'
            if(-not(Test-Path -LiteralPath $outputXml -PathType Leaf)){throw "Parallel branch Robot execution did not produce output.xml. Exit code: $($process.ExitCode)."}
            if([int]$process.ExitCode -ne 0){throw "Parallel branch Robot execution failed with exit code $($process.ExitCode)."}
            $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
            if(Test-Path -LiteralPath $statePath -PathType Leaf){
                $state=Read-DynomaxJson -Path $statePath
                if([string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '') -eq 'FAIL'){throw 'Parallel branch Robot execution failed.'}
            }
        }
        elseif($engine -eq 'PowerShell'){
            $logicalNodeId=[string](Get-DynomaxPropertyValue -Object $step -Name 'workflowNodeId' -DefaultValue ([string]$step.stepId))
            $decision=Get-DynomaxControlFlowDecision -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $logicalNodeId
            $disposition=[string]$decision.Disposition
            if($disposition -eq 'RUN'){
                $continuationDecision=Get-DynomaxContinuationDecision -ContextPath $ContextPath -StepId ([string]$step.stepId)
                if($continuationDecision -eq 'BLOCKED'){throw "Continuation is blocked at physical step '$([string]$step.stepId)'."}
                if($continuationDecision -eq 'REUSE'){
                    Add-DynomaxRunEvent -SqlConfig $sqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Continuation.Reused' -Message "Parallel branch physical step '$([string]$step.stepId)' was reused from the source Run; no Action executed." -Data ([ordered]@{stepId=[string]$step.stepId;workflowNodeId=$logicalNodeId;actionKey=[string]$step.actionId;executionKind='Reused';executed=$false;parallelBranchIndex=$BranchIndex})
                    $reuseState=Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $logicalNodeId -Reused -DeferStateWrite
                    [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $RunId -RunDirectory $RunDirectory -State $reuseState)
                    Write-DynomaxJson -Value $reuseState -Path (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory)
                }else{
                    $stepInputsActivated=$false;$stepFailure=$null
                    try{
                        $stepInputsActivated=[bool](Enter-DynomaxStepInputContext -ContextPath $ContextPath -StepId ([string]$step.stepId))
                        try{[void](Invoke-DynomaxPowerShellAction -DynomaxRoot $DynomaxRoot -ProjectFolder $ProjectFolder -RunId $RunId -Step $step -ContextPath $ContextPath -RunDirectory $RunDirectory -WorkflowDirectory $WorkflowDirectory -PowerShellPath $PowerShellPath -SqlConfig $sqlConfig -StreamOutput:$false -ShowCommand:$false -HeartbeatSeconds $HeartbeatSeconds)}catch{$stepFailure=$_}
                    }finally{
                        if($stepInputsActivated){Exit-DynomaxStepInputContext -ContextPath $ContextPath -StepId ([string]$step.stepId)}
                        $postContext=Read-DynomaxJson -Path $ContextPath
                        Set-DynomaxContextStepInSql -SqlConfig $sqlConfig -RunId $RunId -Context $postContext -StepId ([string]$step.stepId) -PersistedContextCache $persistedContextCache
                    }
                    if($null -ne $stepFailure){
                        $failureState=Fail-DynomaxControlFlowAction -Workflow $workflow -RunDirectory $RunDirectory -NodeId $logicalNodeId -DeferStateWrite
                        [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $RunId -RunDirectory $RunDirectory -State $failureState)
                        Write-DynomaxJson -Value $failureState -Path (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory)
                        throw 'Parallel branch PowerShell Action failed.'
                    }
                    $completionState=Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $logicalNodeId -DeferStateWrite
                    [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $RunId -RunDirectory $RunDirectory -State $completionState)
                    Write-DynomaxJson -Value $completionState -Path (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory)
                }
            }elseif($disposition -eq 'SKIP_FINAL'){
                $versionId=[Guid][string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue [Guid]::Empty)
                Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $RunId -StepOrder ([int]$step.order) -ActionKey ([string]$step.actionId) -ActionVersionId $versionId -Status 'SKIPPED' -Message 'Action was not selected by parallel branch control flow.'
            }elseif($disposition -ne 'DEFER'){
                throw "Unsupported parallel branch control-flow disposition '$disposition' for '$logicalNodeId'."
            }
            $index++
        }else{throw "Unsupported Action engine '$engine' in parallel branch."}
    }
}

$status='Failed';$errorCode=$null;$failureText=$null;$failureStage='Bootstrap'
try{
    if(-not(Test-Path -LiteralPath (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory) -PathType Leaf)){
        [void](Initialize-DynomaxControlFlowState -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory)
    }
    $failureStage='Execution'
    Invoke-DynomaxBranchStepSequence -Sequence $sequence
    $state=Read-DynomaxJson -Path (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory)
    $terminal=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
    if($terminal -ne 'PASS'){throw "Parallel branch ended with terminal status '$terminal'."}
    $status='Passed'
}catch{
    $failureText=[string]$_.Exception.ToString()
    $errorCode='DYNOMAX_PARALLEL_BRANCH_FAILED'
}
finally{
    $state=$null
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(Test-Path -LiteralPath $statePath -PathType Leaf){try{$state=Read-DynomaxJson -Path $statePath}catch{}}
    $executed=if($null -ne $state){@((Get-DynomaxPropertyValue -Object $state -Name 'executedActionNodeIds' -DefaultValue @())|ForEach-Object{[string]$_})}else{@()}
    if($status -ne 'Passed' -and $executed.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($failureText) -and
        $failureText -match '(?i)0x800706ba|rpc_s_server_unavailable|rpc server.*unavailable'){
        $errorCode='DYNOMAX_PARALLEL_BRANCH_TRANSIENT_BOOTSTRAP'
        $failureStage='PreActionBootstrap'
    }elseif($status -ne 'Passed' -and $failureStage -eq 'Execution'){
        $failureStage='ActionExecution'
    }
    $result=[ordered]@{
        schemaVersion=1
        index=$BranchIndex
        status=$status
        startedAtUtc=$startedAt.ToString('o')
        endedAtUtc=[DateTime]::UtcNow.ToString('o')
        errorCode=$errorCode
        failureStage=$failureStage
        branchAttempt=[int]$BranchAttempt
        executedActionNodeIds=$executed
    }
    Write-DynomaxJson -Value $result -Path $ResultPath
}
if($status -eq 'Passed'){exit 0}else{exit 1}
