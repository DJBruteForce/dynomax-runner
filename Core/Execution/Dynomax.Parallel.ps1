Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-DynomaxParallelForkRegionNodeIds {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow)
    $result=New-Object 'System.Collections.Generic.HashSet[string]'
    $controlFlow=Get-DynomaxPropertyValue -Object $Workflow -Name 'controlFlow' -DefaultValue $null
    if($null -eq $controlFlow){Write-Output -NoEnumerate $result;return}
    foreach($fork in @((Get-DynomaxPropertyValue -Object $controlFlow -Name 'nodes' -DefaultValue @())|Where-Object{
        [string](Get-DynomaxPropertyValue -Object $_ -Name 'type' -DefaultValue '') -eq 'Fork' -and
        [int](Get-DynomaxPropertyValue -Object $_ -Name 'maximumParallelism' -DefaultValue 1) -gt 1
    })){
        foreach($branch in @((Get-DynomaxPropertyValue -Object $fork -Name 'branches' -DefaultValue @()))){
            foreach($nodeId in @((Get-DynomaxPropertyValue -Object $branch -Name 'nodeIds' -DefaultValue @()))){
                if(-not [string]::IsNullOrWhiteSpace([string]$nodeId)){[void]$result.Add([string]$nodeId)}
            }
        }
    }
    Write-Output -NoEnumerate $result
    return
}

function Get-DynomaxActiveParallelFork {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RunDirectory)
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){return $null}
    $state=Read-DynomaxJson -Path $statePath
    $fork=Get-DynomaxPropertyValue -Object $state -Name 'activeFork' -DefaultValue $null
    if($null -eq $fork -or [string](Get-DynomaxPropertyValue -Object $fork -Name 'executionMode' -DefaultValue 'Sequential') -ne 'Parallel'){return $null}
    return [pscustomobject][ordered]@{State=$state;Fork=$fork}
}

function Get-DynomaxParallelForkPlanNode {
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][string]$ForkNodeId)
    $matches=@((Get-DynomaxPropertyValue -Object $Workflow.controlFlow -Name 'nodes' -DefaultValue @())|Where-Object{
        [string](Get-DynomaxPropertyValue -Object $_ -Name 'nodeId' -DefaultValue '') -eq $ForkNodeId -and
        [string](Get-DynomaxPropertyValue -Object $_ -Name 'type' -DefaultValue '') -eq 'Fork'
    })
    if($matches.Count -ne 1){throw "Parallel Fork '$ForkNodeId' has no unique compiled control-flow node."}
    return $matches[0]
}

function New-DynomaxParallelBranchWorkflow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)]$ForkNode,
        [Parameter(Mandatory)]$Branch,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$BranchSteps
    )
    $clone=($Workflow|ConvertTo-Json -Depth 100 -Compress|ConvertFrom-Json)
    $controlFlow=$clone.controlFlow
    $joinNodeId=[string](Get-DynomaxPropertyValue -Object $ForkNode -Name 'joinNodeId' -DefaultValue '')
    $targetNodeId=[string](Get-DynomaxPropertyValue -Object $Branch -Name 'targetNodeId' -DefaultValue '')
    $branchIndex=[int](Get-DynomaxPropertyValue -Object $Branch -Name 'index' -DefaultValue 0)
    $forkNodeId=[string](Get-DynomaxPropertyValue -Object $ForkNode -Name 'nodeId' -DefaultValue '')
    $startNodeId=("__parallel_{0}_{1:D3}_start" -f ($forkNodeId -replace '[^A-Za-z0-9_-]','_'),$branchIndex)
    $terminalNodeId=("__parallel_{0}_{1:D3}_succeed" -f ($forkNodeId -replace '[^A-Za-z0-9_-]','_'),$branchIndex)
    $region=New-Object 'System.Collections.Generic.HashSet[string]'
    foreach($nodeId in @((Get-DynomaxPropertyValue -Object $Branch -Name 'nodeIds' -DefaultValue @()))){[void]$region.Add([string]$nodeId)}
    if($region.Count -gt 0 -and (-not $region.Contains($targetNodeId))){throw "Parallel branch $branchIndex target '$targetNodeId' is outside its compiled region."}
    $nodes=[System.Collections.Generic.List[object]]::new()
    foreach($node in @((Get-DynomaxPropertyValue -Object $controlFlow -Name 'nodes' -DefaultValue @()))){
        if($region.Contains([string]$node.nodeId)){$nodes.Add($node)}
    }
    # A branch-local control-flow plan still needs a real System Start node. Pointing
    # startNodeId at the first Action makes Initialize-DynomaxControlFlowState call
    # Set-DynomaxSystemNodeState for an Action, which fails before any branch Action runs.
    $nodes.Add([pscustomobject][ordered]@{nodeId=$startNodeId;type='Start';displayName='Parallel branch start'})
    $nodes.Add([pscustomobject][ordered]@{nodeId=$terminalNodeId;type='Succeed';displayName='Parallel branch completed'})
    $edges=[System.Collections.Generic.List[object]]::new()
    foreach($edge in @((Get-DynomaxPropertyValue -Object $controlFlow -Name 'edges' -DefaultValue @()))){
        $from=[string](Get-DynomaxPropertyValue -Object $edge -Name 'fromNodeId' -DefaultValue '')
        $to=[string](Get-DynomaxPropertyValue -Object $edge -Name 'toNodeId' -DefaultValue '')
        $when=[string](Get-DynomaxPropertyValue -Object $edge -Name 'when' -DefaultValue '')
        if(-not $region.Contains($from) -or $when -eq 'Failure'){continue}
        if($region.Contains($to)){$edges.Add($edge);continue}
        if($to -eq $joinNodeId){
            $copy=($edge|ConvertTo-Json -Depth 20 -Compress|ConvertFrom-Json)
            $copy.toNodeId=$terminalNodeId
            $edges.Add($copy)
        }
    }
    $startTargetNodeId=$(if($region.Count -eq 0){$terminalNodeId}else{$targetNodeId})
    $edges.Add([pscustomobject][ordered]@{
        edgeId=("__parallel_{0}_{1:D3}_start_success" -f ($forkNodeId -replace '[^A-Za-z0-9_-]','_'),$branchIndex)
        fromNodeId=$startNodeId
        toNodeId=$startTargetNodeId
        when='Success'
        priority=0
    })
    $controlFlow.startNodeId=$startNodeId
    $controlFlow.nodes=$nodes.ToArray()
    $controlFlow.edges=$edges.ToArray()
    $clone.steps=@($BranchSteps)
    if($clone.PSObject.Properties['discovery']){[void]$clone.PSObject.Properties.Remove('discovery')}
    return $clone
}

function Merge-DynomaxParallelBranchContexts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ParentContextPath,
        [Parameter(Mandatory)][object[]]$BranchExecutions
    )
    $parent=Read-DynomaxJson -Path $ParentContextPath
    $parentPool=Get-DynomaxPropertyValue -Object $parent -Name 'runDataPool' -DefaultValue $null
    if($null -eq $parentPool){$parentPool=[pscustomobject][ordered]@{steps=[pscustomobject][ordered]@{}};Set-DynomaxDynamicContextProperty -Object $parent -Name 'runDataPool' -Value $parentPool}
    $parentSteps=Get-DynomaxPropertyValue -Object $parentPool -Name 'steps' -DefaultValue $null
    if($null -eq $parentSteps){$parentSteps=[pscustomobject][ordered]@{};Set-DynomaxDynamicContextProperty -Object $parentPool -Name 'steps' -Value $parentSteps}
    $sensitive=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $parent -Name 'sensitiveKeys' -DefaultValue @())){if([string]$key){$sensitive[[string]$key]=$true}}
    foreach($execution in @($BranchExecutions|Sort-Object Index)){
        if([string]$execution.Result.status -ne 'Passed'){continue}
        $child=Read-DynomaxJson -Path ([string]$execution.ContextPath)
        $childPool=Get-DynomaxPropertyValue -Object $child -Name 'runDataPool' -DefaultValue $null
        $childSteps=if($null -ne $childPool){Get-DynomaxPropertyValue -Object $childPool -Name 'steps' -DefaultValue $null}else{$null}
        foreach($step in @($execution.Steps|Sort-Object order)){
            $stepId=[string]$step.stepId
            $entryProperty=if($null -ne $childSteps){$childSteps.PSObject.Properties[$stepId]}else{$null}
            if($null -eq $entryProperty){continue}
            $entry=$entryProperty.Value
            Set-DynomaxDynamicContextProperty -Object $parentSteps -Name $stepId -Value $entry
            $outputs=Get-DynomaxPropertyValue -Object $entry -Name 'outputs' -DefaultValue $null
            if($null -eq $outputs){continue}
            foreach($property in @($outputs.PSObject.Properties)){
                $output=$property.Value
                if(-not [bool](Get-DynomaxPropertyValue -Object $output -Name 'available' -DefaultValue $false)){continue}
                $name=[string]$property.Name
                Set-DynomaxDynamicContextProperty -Object $parent.values -Name $name -Value (Get-DynomaxPropertyValue -Object $output -Name 'value' -DefaultValue $null)
                if([string](Get-DynomaxPropertyValue -Object $output -Name 'classification' -DefaultValue 'Normal') -eq 'SensitiveRedacted'){$sensitive[$name]=$true}else{[void]$sensitive.Remove($name)}
            }
        }
    }
    Set-DynomaxDynamicContextProperty -Object $parent -Name 'sensitiveKeys' -Value @($sensitive.Keys|Sort-Object)
    Write-DynomaxJson -Value $parent -Path $ParentContextPath
    return $parent
}

function Start-DynomaxParallelBranchProcess {
    param(
        [Parameter(Mandatory)]$Descriptor,
        [Parameter(Mandatory)][string]$PowerShellPath,
        [Parameter(Mandatory)][string]$BranchRunnerPath,
        [Parameter(Mandatory)][string]$DynomaxRoot,
        [Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)][string]$WorkflowDirectory,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$PythonPath,
        [int]$BranchAttempt=1,
        [int]$TimeoutSeconds,
        [int]$HeartbeatSeconds
    )
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$BranchRunnerPath,
        '-DynomaxRoot',$DynomaxRoot,'-ProjectFolder',$ProjectFolder,'-WorkflowDirectory',$WorkflowDirectory,
        '-BranchWorkflowPath',[string]$Descriptor.WorkflowPath,'-BranchStepsPath',[string]$Descriptor.StepsPath,
        '-ContextPath',[string]$Descriptor.ContextPath,'-RunDirectory',[string]$Descriptor.Directory,
        '-RunId',[string]$RunId,'-BranchIndex',[string]$Descriptor.Index,'-BranchAttempt',[string]$BranchAttempt,'-ResultPath',[string]$Descriptor.ResultPath,
        '-PythonPath',$PythonPath,'-PowerShellPath',$PowerShellPath,'-TimeoutSeconds',[string]$TimeoutSeconds,'-HeartbeatSeconds',[string]$HeartbeatSeconds)
    $startInfo=New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName=$PowerShellPath
    $startInfo.Arguments=(($args|ForEach-Object{ConvertTo-DynomaxNativeArgument ([string]$_)}) -join ' ')
    $startInfo.UseShellExecute=$false
    $startInfo.RedirectStandardOutput=$true
    $startInfo.RedirectStandardError=$true
    $startInfo.CreateNoWindow=$true
    $process=New-Object System.Diagnostics.Process
    $process.StartInfo=$startInfo
    if(-not $process.Start()){throw "Could not start parallel branch $($Descriptor.Index)."}
    return [pscustomobject][ordered]@{
        Index=[int]$Descriptor.Index;Descriptor=$Descriptor;BranchAttempt=[int]$BranchAttempt;Process=$process;
        StdoutTask=$process.StandardOutput.ReadToEndAsync();StderrTask=$process.StandardError.ReadToEndAsync()
    }
}

function Invoke-DynomaxPendingParallelFork {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Sequence,
        [Parameter(Mandatory)][string]$DynomaxRoot,
        [Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)][string]$WorkflowDirectory,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$ContextPath,
        [Parameter(Mandatory)][string]$PowerShellPath,
        [Parameter(Mandatory)][string]$PythonPath,
        [Parameter(Mandatory)]$SqlConfig,
        [hashtable]$PersistedContextCache,
        [int]$TimeoutSeconds=0,
        [int]$HeartbeatSeconds=15
    )
    $active=Get-DynomaxActiveParallelFork -RunDirectory $RunDirectory
    if($null -eq $active){return [pscustomobject][ordered]@{Executed=$false;ConsumedStepOrders=@();Terminal=$false}}
    $state=$active.State;$fork=$active.Fork
    $forkId=[string]$fork.forkNodeId
    $forkNode=Get-DynomaxParallelForkPlanNode -Workflow $Workflow -ForkNodeId $forkId
    $max=[int](Get-DynomaxPropertyValue -Object $fork -Name 'maximumParallelism' -DefaultValue 1)
    $branches=@((Get-DynomaxPropertyValue -Object $forkNode -Name 'branches' -DefaultValue @())|Sort-Object index)
    if($branches.Count -lt 2){throw "Parallel Fork '$forkId' has no compiled branch metadata."}
    $parallelRoot=Ensure-DynomaxDirectory -Path (Join-Path $RunDirectory ('parallel\'+($forkId -replace '[^A-Za-z0-9_.-]','_')))
    $descriptors=[System.Collections.Generic.List[object]]::new()
    $selectedOrders=New-Object 'System.Collections.Generic.HashSet[int]'
    # executionSlot is a physical occurrence number for a logical Action, not a Fork branch identity.
    # All sibling branches on the same Fork visit therefore consume the same occurrence slot.
    # A later bounded revisit of this same Fork advances every sibling to the next occurrence slot.
    $completedForkVisits=@((Get-DynomaxPropertyValue -Object $state -Name 'forkHistory' -DefaultValue @()) | Where-Object {
        [string](Get-DynomaxPropertyValue -Object $_ -Name 'forkNodeId' -DefaultValue '') -eq $forkId
    }).Count
    $slot=1+[int]$completedForkVisits
    foreach($branch in $branches){
        $index=[int]$branch.index
        $nodeIds=New-Object 'System.Collections.Generic.HashSet[string]'
        foreach($nodeId in @((Get-DynomaxPropertyValue -Object $branch -Name 'nodeIds' -DefaultValue @()))){[void]$nodeIds.Add([string]$nodeId)}
        $steps=@($Sequence|Where-Object{
            $nodeIds.Contains([string](Get-DynomaxPropertyValue -Object $_ -Name 'workflowNodeId' -DefaultValue ([string]$_.stepId))) -and
            [int](Get-DynomaxPropertyValue -Object $_ -Name 'executionSlot' -DefaultValue 1) -eq $slot
        }|Sort-Object order)
        foreach($step in $steps){if(-not $selectedOrders.Add([int]$step.order)){throw "Parallel Fork '$forkId' selected duplicate physical step order '$([int]$step.order)'."}}
        $branchDir=Ensure-DynomaxDirectory -Path (Join-Path $parallelRoot ("branch-{0:D3}" -f $index))
        $branchContext=Join-Path $branchDir 'context.json';Copy-Item -LiteralPath $ContextPath -Destination $branchContext -Force
        $branchWorkflow=New-DynomaxParallelBranchWorkflow -Workflow $Workflow -ForkNode $forkNode -Branch $branch -BranchSteps $steps
        $workflowPath=Join-Path $branchDir 'workflow.json';Write-DynomaxJson -Value $branchWorkflow -Path $workflowPath
        $stepsPath=Join-Path $branchDir 'steps.json';Write-DynomaxJson -Value @($steps) -Path $stepsPath
        $descriptors.Add([pscustomobject][ordered]@{Index=$index;Branch=$branch;Steps=$steps;Directory=$branchDir;ContextPath=$branchContext;WorkflowPath=$workflowPath;StepsPath=$stepsPath;ResultPath=(Join-Path $branchDir 'branch-result.json');BranchAttempt=1})
    }

    Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Runtime.ParallelForkStarted' -Message "Parallel Fork '$forkId' started bounded isolated branch execution." -Data ([ordered]@{forkNodeId=$forkId;branchCount=$branches.Count;maximumParallelism=$max})
    $runner=Join-Path $DynomaxRoot 'Core\Execution\Invoke-DynomaxParallelBranch.ps1'
    $pending=New-Object 'System.Collections.Generic.Queue[object]'
    foreach($descriptor in $descriptors){$pending.Enqueue($descriptor)}
    $activeProcesses=@{}
    $executions=[System.Collections.Generic.List[object]]::new()
    $failObserved=$false
    try{
        while(($pending.Count -gt 0 -and -not $failObserved) -or $activeProcesses.Count -gt 0){
            while(-not $failObserved -and $pending.Count -gt 0 -and $activeProcesses.Count -lt $max){
                $descriptor=$pending.Dequeue()
                if($activeProcesses.Count -gt 0){Start-Sleep -Milliseconds 100}
                $attempt=[int](Get-DynomaxPropertyValue -Object $descriptor -Name 'BranchAttempt' -DefaultValue 1)
                $handle=Start-DynomaxParallelBranchProcess -Descriptor $descriptor -PowerShellPath $PowerShellPath -BranchRunnerPath $runner -DynomaxRoot $DynomaxRoot -ProjectFolder $ProjectFolder -WorkflowDirectory $WorkflowDirectory -RunId $RunId -PythonPath $PythonPath -BranchAttempt $attempt -TimeoutSeconds $TimeoutSeconds -HeartbeatSeconds $HeartbeatSeconds
                $activeProcesses[[string]$descriptor.Index]=$handle
            }
            if($activeProcesses.Count -eq 0){break}
            Start-Sleep -Milliseconds 100
            $completed=@($activeProcesses.Values|Where-Object{$_.Process.HasExited}|Sort-Object Index)
            foreach($handle in $completed){
                $descriptor=$handle.Descriptor;$process=$handle.Process
                try{$stdout=$handle.StdoutTask.GetAwaiter().GetResult()}catch{$stdout=''}
                try{$stderr=$handle.StderrTask.GetAwaiter().GetResult()}catch{$stderr=''}
                $logPath=Join-Path $descriptor.Directory 'branch-worker.log'
                [System.IO.File]::WriteAllText($logPath,((@("EXIT CODE: $($process.ExitCode)",'--- STDOUT ---',$stdout,'--- STDERR ---',$stderr)-join [Environment]::NewLine)),(New-Object System.Text.UTF8Encoding($false)))
                $result=$null
                if(Test-Path -LiteralPath $descriptor.ResultPath -PathType Leaf){try{$result=Read-DynomaxJson -Path $descriptor.ResultPath}catch{}}
                if($null -eq $result){$result=[pscustomobject][ordered]@{schemaVersion=1;index=[int]$descriptor.Index;status='Failed';startedAtUtc=$null;endedAtUtc=[DateTime]::UtcNow.ToString('o');errorCode='DYNOMAX_PARALLEL_BRANCH_RESULT_MISSING';executedActionNodeIds=@()}}
                $isTransientBootstrap=[string]$result.status -ne 'Passed' -and [string](Get-DynomaxPropertyValue -Object $result -Name 'errorCode' -DefaultValue '') -eq 'DYNOMAX_PARALLEL_BRANCH_TRANSIENT_BOOTSTRAP'
                $branchAttempt=[int](Get-DynomaxPropertyValue -Object $descriptor -Name 'BranchAttempt' -DefaultValue 1)
                $process.Dispose();$activeProcesses.Remove([string]$descriptor.Index)
                if($isTransientBootstrap -and $branchAttempt -lt 2){
                    Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Warning' -EventType 'Runtime.ParallelBranchBootstrapRetry' -Message "Parallel Fork '$forkId' branch $([int]$descriptor.Index) hit a transient pre-Action RPC bootstrap failure; retrying once in a clean branch workspace." -Data ([ordered]@{forkNodeId=$forkId;branchIndex=[int]$descriptor.Index;completedAttempt=$branchAttempt;nextAttempt=$branchAttempt+1;errorCode='DYNOMAX_PARALLEL_BRANCH_TRANSIENT_BOOTSTRAP'})
                    Copy-Item -LiteralPath $ContextPath -Destination ([string]$descriptor.ContextPath) -Force
                    foreach($relative in @('control-flow-state.json','robot-result','attempt-scratch','attempt-recorder','generated-workflow.robot','robot-console.log','branch-result.json','branch-worker.log')){
                        $candidate=Join-Path ([string]$descriptor.Directory) $relative
                        if(Test-Path -LiteralPath $candidate){Remove-Item -LiteralPath $candidate -Recurse -Force -ErrorAction SilentlyContinue}
                    }
                    $descriptor.BranchAttempt=$branchAttempt+1
                    Start-Sleep -Milliseconds (200 + (50 * [int]$descriptor.Index))
                    $pending.Enqueue($descriptor)
                    continue
                }
                if([string]$result.status -ne 'Passed'){$failObserved=$true}
                $executions.Add([pscustomobject][ordered]@{Index=[int]$descriptor.Index;Descriptor=$descriptor;Steps=$descriptor.Steps;ContextPath=$descriptor.ContextPath;Result=$result;Launched=$true})
            }
        }
    }finally{
        foreach($handle in @($activeProcesses.Values)){
            try{if(-not $handle.Process.HasExited){$handle.Process.Kill();$handle.Process.WaitForExit()}}catch{}
            try{$handle.Process.Dispose()}catch{}
        }
    }
    while($pending.Count -gt 0){
        $descriptor=$pending.Dequeue()
        $result=[pscustomobject][ordered]@{schemaVersion=1;index=[int]$descriptor.Index;status='Skipped';startedAtUtc=$null;endedAtUtc=[DateTime]::UtcNow.ToString('o');errorCode=$null;executedActionNodeIds=@()}
        Write-DynomaxJson -Value $result -Path $descriptor.ResultPath
        $executions.Add([pscustomobject][ordered]@{Index=[int]$descriptor.Index;Descriptor=$descriptor;Steps=$descriptor.Steps;ContextPath=$descriptor.ContextPath;Result=$result;Launched=$false})
    }
    $orderedExecutions=@($executions|Sort-Object Index)
    $mergedContext=Merge-DynomaxParallelBranchContexts -ParentContextPath $ContextPath -BranchExecutions $orderedExecutions
    if($null -ne $PersistedContextCache){Set-DynomaxContextValuesInSql -SqlConfig $SqlConfig -RunId $RunId -Context $mergedContext -PersistedContextCache $PersistedContextCache}
    $branchResults=@($orderedExecutions|ForEach-Object{$_.Result})
    $completedState=Complete-DynomaxParallelFork -Workflow $Workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -BranchResults $branchResults -DeferStateWrite
    [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $SqlConfig -RunId $RunId -RunDirectory $RunDirectory -State $completedState)
    Write-DynomaxJson -Value $completedState -Path (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory)
    $timing=[ordered]@{schemaVersion=1;forkNodeId=$forkId;maximumParallelism=$max;startedAtUtc=[string]$fork.startedAtUtc;endedAtUtc=[DateTime]::UtcNow.ToString('o');branches=@($branchResults|Sort-Object index|ForEach-Object{[ordered]@{index=[int]$_.index;status=[string]$_.status;startedAtUtc=$_.startedAtUtc;endedAtUtc=$_.endedAtUtc}})}
    $timingLine=$timing|ConvertTo-Json -Depth 20 -Compress
    Add-Content -LiteralPath (Join-Path $RunDirectory 'parallel-execution.jsonl') -Value $timingLine -Encoding UTF8
    Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel $(if($failObserved){'Error'}else{'Info'}) -EventType 'Runtime.ParallelForkCompleted' -Message $(if($failObserved){"Parallel Fork '$forkId' completed with deterministic FailFast failure aggregation."}else{"Parallel Fork '$forkId' completed successfully."}) -Data ([ordered]@{forkNodeId=$forkId;branchCount=$branches.Count;maximumParallelism=$max;failed=$failObserved})
    $consumed=@($orderedExecutions|Where-Object{$_.Launched}|ForEach-Object{$_.Steps}|ForEach-Object{[int]$_.order}|Sort-Object -Unique)
    $terminal=[string](Get-DynomaxPropertyValue -Object $completedState -Name 'terminalStatus' -DefaultValue '')
    return [pscustomobject][ordered]@{Executed=$true;ConsumedStepOrders=$consumed;Terminal=[bool]$terminal;TerminalStatus=$terminal}
}
