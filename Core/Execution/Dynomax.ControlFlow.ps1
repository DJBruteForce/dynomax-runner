Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Test-DynomaxControlFlowEnabled {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow)
    $plan=Get-DynomaxPropertyValue -Object $Workflow -Name 'controlFlow' -DefaultValue $null
    return $null -ne $plan
}

function Get-DynomaxControlFlowStatePath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RunDirectory)
    return Join-Path $RunDirectory 'control-flow-state.json'
}

function Get-DynomaxControlFlowNodeMap {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan)
    $map=@{}
    foreach($node in @((Get-DynomaxPropertyValue -Object $Plan -Name 'nodes' -DefaultValue @()))){
        $id=[string](Get-DynomaxPropertyValue -Object $node -Name 'nodeId' -DefaultValue '')
        if(-not $id){throw 'Control-flow node has no nodeId.'}
        if($map.ContainsKey($id)){throw "Control-flow node '$id' is duplicated."}
        $map[$id]=$node
    }
    return $map
}

function Get-DynomaxControlFlowOutgoing {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)][string]$NodeId)
    return @((Get-DynomaxPropertyValue -Object $Plan -Name 'edges' -DefaultValue @()) |
        Where-Object { [string](Get-DynomaxPropertyValue -Object $_ -Name 'fromNodeId' -DefaultValue '') -eq $NodeId } |
        Sort-Object @{Expression={ [int](Get-DynomaxPropertyValue -Object $_ -Name 'priority' -DefaultValue 0) }}, @{Expression={ [string](Get-DynomaxPropertyValue -Object $_ -Name 'edgeId' -DefaultValue '') }})
}

function Get-DynomaxDiscoveryTargetNodeId {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow)
    $discovery=Get-DynomaxPropertyValue -Object $Workflow -Name 'discovery' -DefaultValue $null
    if($null -eq $discovery){return ''}
    $enabled=[bool](Get-DynomaxPropertyValue -Object $discovery -Name 'enabled' -DefaultValue $false)
    if(-not $enabled){return ''}
    return [string](Get-DynomaxPropertyValue -Object $discovery -Name 'targetNodeId' -DefaultValue '')
}

function Test-DynomaxControlFlowCanReachNode {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)][string]$FromNodeId,[Parameter(Mandatory)][string]$TargetNodeId)
    if($FromNodeId -eq $TargetNodeId){return $true}
    $nodes=Get-DynomaxControlFlowNodeMap -Plan $Plan
    if(-not $nodes.ContainsKey($FromNodeId) -or -not $nodes.ContainsKey($TargetNodeId)){return $false}
    $queue=New-Object 'System.Collections.Generic.Queue[string]'
    $seen=New-Object 'System.Collections.Generic.HashSet[string]'
    $queue.Enqueue($FromNodeId)
    [void]$seen.Add($FromNodeId)
    $limit=(@($nodes.Keys).Count + @((Get-DynomaxPropertyValue -Object $Plan -Name 'edges' -DefaultValue @())).Count + 8)
    for($i=0;$queue.Count -gt 0 -and $i -lt $limit;$i++){
        $current=$queue.Dequeue()
        foreach($edge in @(Get-DynomaxControlFlowOutgoing -Plan $Plan -NodeId $current)){
            if([string](Get-DynomaxPropertyValue -Object $edge -Name 'when' -DefaultValue '') -eq 'Failure'){continue}
            $next=[string](Get-DynomaxPropertyValue -Object $edge -Name 'toNodeId' -DefaultValue '')
            if(-not $next){continue}
            if($next -eq $TargetNodeId){return $true}
            if($nodes.ContainsKey($next) -and $seen.Add($next)){$queue.Enqueue($next)}
        }
    }
    return $false
}

function Test-DynomaxDiscoveryReachableFromState {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$CurrentNodeId,[Parameter(Mandatory)][string]$TargetNodeId)
    if(Test-DynomaxControlFlowCanReachNode -Plan $Plan -FromNodeId $CurrentNodeId -TargetNodeId $TargetNodeId){return $true}
    $fork=Get-DynomaxPropertyValue -Object $State -Name 'activeFork' -DefaultValue $null
    if($null -ne $fork){
        foreach($branch in @((Get-DynomaxPropertyValue -Object $fork -Name 'branches' -DefaultValue @()))){
            $status=[string](Get-DynomaxPropertyValue -Object $branch -Name 'status' -DefaultValue '')
            if($status -notin @('Pending','Running')){continue}
            $start=[string](Get-DynomaxPropertyValue -Object $branch -Name 'targetNodeId' -DefaultValue '')
            if($start -and (Test-DynomaxControlFlowCanReachNode -Plan $Plan -FromNodeId $start -TargetNodeId $TargetNodeId)){return $true}
        }
        $join=[string](Get-DynomaxPropertyValue -Object $fork -Name 'joinNodeId' -DefaultValue '')
        if($join -and (Test-DynomaxControlFlowCanReachNode -Plan $Plan -FromNodeId $join -TargetNodeId $TargetNodeId)){return $true}
    }
    return $false
}

function Stop-DynomaxDiscoveryForUnreachableTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$SelectedNodeId,[Parameter(Mandatory)][string]$TargetNodeId)
    $State.nextActionNodeId=$null
    $State.terminalNodeId=$SelectedNodeId
    $State.terminalStatus='BLOCKED'
    $State.discoveryTargetReached=$false
    $State.discoveryBlockReason="Runtime-selected control-flow state reaches '$SelectedNodeId' and cannot reach requested Discovery target '$TargetNodeId'. Dynomax did not force a different Condition, Fork branch or Loop outcome."
    $State.discoveryCompletedAtUtc=[DateTime]::UtcNow.ToString('o')
}

function Get-DynomaxControlFlowContextValue {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)]$Binding)
    $kind=[string](Get-DynomaxPropertyValue -Object $Binding -Name 'kind' -DefaultValue '')
    switch($kind){
        'Literal' { return Get-DynomaxPropertyValue -Object $Binding -Name 'value' -DefaultValue $null }
        'NodeOutput' {
            $output=[string](Get-DynomaxPropertyValue -Object $Binding -Name 'outputName' -DefaultValue '')
            if(-not $output){throw 'Control-flow NodeOutput binding has no outputName.'}
            $values=Get-DynomaxPropertyValue -Object $Context -Name 'values' -DefaultValue $null
            if($null -eq $values){throw 'Runtime context has no values object.'}
            $property=$values.PSObject.Properties[$output]
            if($null -eq $property){throw "Control flow requires earlier output '$output', but it is not present in runtime context."}
            return $property.Value
        }
        default { throw "Control-flow binding kind '$kind' is not supported by this Core release." }
    }
}

function Test-DynomaxCondition {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Node,[Parameter(Mandatory)]$Context)
    $operator=[string](Get-DynomaxPropertyValue -Object $Node -Name 'operator' -DefaultValue '')
    $leftBinding=Get-DynomaxPropertyValue -Object $Node -Name 'left' -DefaultValue $null
    if($null -eq $leftBinding){throw "Control-flow node '$([string]$Node.nodeId)' has no left binding."}
    $left=Get-DynomaxControlFlowContextValue -Context $Context -Binding $leftBinding
    $rightBinding=Get-DynomaxPropertyValue -Object $Node -Name 'right' -DefaultValue $null
    $right=if($null -eq $rightBinding){$null}else{Get-DynomaxControlFlowContextValue -Context $Context -Binding $rightBinding}
    switch($operator){
        'Equals' { return $left -eq $right }
        'NotEquals' { return $left -ne $right }
        'GreaterThan' { return $left -gt $right }
        'GreaterThanOrEqual' { return $left -ge $right }
        'LessThan' { return $left -lt $right }
        'LessThanOrEqual' { return $left -le $right }
        'Contains' {
            if($null -eq $left){return $false}
            if($left -is [string]){return ([string]$left).IndexOf([string]$right,[System.StringComparison]::OrdinalIgnoreCase) -ge 0}
            return @($left) -contains $right
        }
        'NotContains' {
            if($null -eq $left){return $true}
            if($left -is [string]){return ([string]$left).IndexOf([string]$right,[System.StringComparison]::OrdinalIgnoreCase) -lt 0}
            return -not (@($left) -contains $right)
        }
        'IsEmpty' {
            if($null -eq $left){return $true}
            if($left -is [string]){return [string]::IsNullOrWhiteSpace([string]$left)}
            if($left -is [System.Collections.IEnumerable]){return @($left).Count -eq 0}
            return $false
        }
        'IsNotEmpty' {
            if($null -eq $left){return $false}
            if($left -is [string]){return -not [string]::IsNullOrWhiteSpace([string]$left)}
            if($left -is [System.Collections.IEnumerable]){return @($left).Count -gt 0}
            return $true
        }
        'IsTrue' { return [bool]$left }
        'IsFalse' { return -not [bool]$left }
        default { throw "Condition operator '$operator' is not supported by this Core control-flow release." }
    }
}

function Add-DynomaxControlFlowTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$FromNodeId,[Parameter(Mandatory)][string]$ToNodeId,
        [Parameter(Mandatory)][string]$When,[string]$EdgeId,[Nullable[bool]]$ConditionResult=$null,[string]$Operator,
        [string]$Event,[string]$BranchLabel,[Nullable[int]]$BranchIndex=$null,[Nullable[int]]$LoopIteration=$null)
    $transition=[ordered]@{
        sequence=(@($State.transitions).Count + 1)
        atUtc=[DateTime]::UtcNow.ToString('o')
        fromNodeId=$FromNodeId
        toNodeId=$ToNodeId
        when=$When
        edgeId=$EdgeId
    }
    if($null -ne $ConditionResult){$transition.conditionResult=[bool]$ConditionResult}
    if($Operator){$transition.operator=$Operator}
    if($Event){$transition.event=$Event}
    if($BranchLabel){$transition.branchLabel=$BranchLabel}
    if($null -ne $BranchIndex){$transition.branchIndex=[int]$BranchIndex}
    if($null -ne $LoopIteration){$transition.loopIteration=[int]$LoopIteration}
    $State.transitions=@($State.transitions)+@([pscustomobject]$transition)
}

function Get-DynomaxLoopState {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State,[Parameter(Mandatory)]$Node)
    $nodeId=[string]$Node.nodeId
    foreach($existing in @($State.loops)){
        if([string]$existing.nodeId -eq $nodeId){return $existing}
    }
    $created=[pscustomobject][ordered]@{
        nodeId=$nodeId
        startedAtUtc=[DateTime]::UtcNow.ToString('o')
        maximumIterations=[int](Get-DynomaxPropertyValue -Object $Node -Name 'maximumIterations' -DefaultValue 0)
        overallTimeoutSeconds=[int](Get-DynomaxPropertyValue -Object $Node -Name 'overallTimeoutSeconds' -DefaultValue 0)
        iterations=0
        completed=$false
        stopReason=$null
        completedAtUtc=$null
    }
    $State.loops=@($State.loops)+@($created)
    return $created
}

function Fail-DynomaxLoop {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State,[Parameter(Mandatory)]$LoopState,[Parameter(Mandatory)][string]$Reason)
    $LoopState.completed=$true
    $LoopState.stopReason=$Reason
    $LoopState.completedAtUtc=[DateTime]::UtcNow.ToString('o')
    $State.nextActionNodeId=$null
    $State.terminalNodeId=[string]$LoopState.nodeId
    $State.terminalStatus='FAIL'
}

function Start-DynomaxFork {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$State,[Parameter(Mandatory)]$ForkNode)
    if($null -ne $State.activeFork){throw 'Nested Fork execution is not supported by this Core release.'}
    $forkId=[string]$ForkNode.nodeId
    $joinId=[string](Get-DynomaxPropertyValue -Object $ForkNode -Name 'joinNodeId' -DefaultValue '')
    if(-not $joinId){throw "Fork '$forkId' has no paired joinNodeId."}
    $edges=@(Get-DynomaxControlFlowOutgoing -Plan $Plan -NodeId $forkId | Where-Object { [string]$_.when -eq 'Branch' })
    if($edges.Count -lt 2){throw "Fork '$forkId' requires at least two Branch edges."}
    $branches=@()
    $index=0
    foreach($edge in $edges){
        $branches+=,[pscustomobject][ordered]@{
            index=$index
            edgeId=[string]$edge.edgeId
            label=[string](Get-DynomaxPropertyValue -Object $edge -Name 'label' -DefaultValue ("Branch {0}" -f ($index+1)))
            targetNodeId=[string]$edge.toNodeId
            status='Pending'
            startedAtUtc=$null
            completedAtUtc=$null
        }
        $index++
    }
    $State.activeFork=[pscustomobject][ordered]@{
        forkNodeId=$forkId
        joinNodeId=$joinId
        failurePolicy=[string](Get-DynomaxPropertyValue -Object $ForkNode -Name 'failurePolicy' -DefaultValue 'FailFast')
        startedAtUtc=[DateTime]::UtcNow.ToString('o')
        completedAtUtc=$null
        currentBranchIndex=-1
        branches=$branches
    }
}

function Start-DynomaxNextForkBranch {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State)
    $fork=$State.activeFork
    if($null -eq $fork){return ''}
    $pending=@($fork.branches | Where-Object { [string]$_.status -eq 'Pending' } | Sort-Object index)
    if($pending.Count -eq 0){return ''}
    $branch=$pending[0]
    $branch.status='Running'
    $branch.startedAtUtc=[DateTime]::UtcNow.ToString('o')
    $fork.currentBranchIndex=[int]$branch.index
    Add-DynomaxControlFlowTransition -State $State -FromNodeId ([string]$fork.forkNodeId) -ToNodeId ([string]$branch.targetNodeId) -When 'Branch' -EdgeId ([string]$branch.edgeId) -Event 'ForkBranchStarted' -BranchLabel ([string]$branch.label) -BranchIndex ([int]$branch.index)
    return [string]$branch.targetNodeId
}

function Complete-DynomaxForkBranchAtJoin {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$JoinNodeId)
    $fork=$State.activeFork
    if($null -eq $fork -or [string]$fork.joinNodeId -ne $JoinNodeId){throw "Join '$JoinNodeId' was reached without its active Fork."}
    $currentIndex=[int]$fork.currentBranchIndex
    $current=@($fork.branches | Where-Object { [int]$_.index -eq $currentIndex })
    if($current.Count -ne 1){throw "Fork '$([string]$fork.forkNodeId)' has no active branch at Join '$JoinNodeId'."}
    $current[0].status='Completed'
    $current[0].completedAtUtc=[DateTime]::UtcNow.ToString('o')
    $next=Start-DynomaxNextForkBranch -State $State
    if($next){return $next}

    $fork.completedAtUtc=[DateTime]::UtcNow.ToString('o')
    $State.forkHistory=@($State.forkHistory)+@($fork)
    $State.activeFork=$null
    $joinEdges=@(Get-DynomaxControlFlowOutgoing -Plan $Plan -NodeId $JoinNodeId | Where-Object { [string]$_.when -eq 'Success' })
    if($joinEdges.Count -ne 1){throw "Join '$JoinNodeId' requires exactly one Success edge."}
    $edge=$joinEdges[0]
    Add-DynomaxControlFlowTransition -State $State -FromNodeId $JoinNodeId -ToNodeId ([string]$edge.toNodeId) -When 'Success' -EdgeId ([string]$edge.edgeId) -Event 'JoinComplete'
    return [string]$edge.toNodeId
}

function Test-DynomaxDiscoveryAfterMove {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$CurrentNodeId)
    $target=Get-DynomaxDiscoveryTargetNodeId -Workflow $Workflow
    if(-not $target -or $CurrentNodeId -eq $target){return $true}
    if(Test-DynomaxDiscoveryReachableFromState -Plan $Workflow.controlFlow -State $State -CurrentNodeId $CurrentNodeId -TargetNodeId $target){return $true}
    Stop-DynomaxDiscoveryForUnreachableTarget -State $State -SelectedNodeId $CurrentNodeId -TargetNodeId $target
    return $false
}

function Move-DynomaxControlFlowToNextExecutable {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)]$Context,[Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$FromNodeId,[Parameter(Mandatory)][string]$Outcome)
    $plan=$Workflow.controlFlow
    $nodes=Get-DynomaxControlFlowNodeMap -Plan $plan
    $initialEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $FromNodeId | Where-Object { [string]$_.when -eq $Outcome })
    if($initialEdges.Count -ne 1){throw "Control-flow node '$FromNodeId' requires exactly one '$Outcome' edge at runtime; found $($initialEdges.Count)."}
    $initialEdge=$initialEdges[0]
    $currentId=[string]$initialEdge.toNodeId
    if(-not $nodes.ContainsKey($currentId)){throw "Control-flow edge '$([string]$initialEdge.edgeId)' targets missing node '$currentId'."}
    Add-DynomaxControlFlowTransition -State $State -FromNodeId $FromNodeId -ToNodeId $currentId -When $Outcome -EdgeId ([string]$initialEdge.edgeId)
    if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}

    $max=(@($nodes.Keys).Count * 4 + 16)
    for($hop=0;$hop -lt $max;$hop++){
        $current=$nodes[$currentId]
        switch([string]$current.type){
            'Action' {
                $State.nextActionNodeId=$currentId
                $State.terminalNodeId=$null
                $State.terminalStatus=$null
                return
            }
            'Condition' {
                $result=[bool](Test-DynomaxCondition -Node $current -Context $Context)
                $conditionOutcome=if($result){'True'}else{'False'}
                $conditionEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq $conditionOutcome })
                if($conditionEdges.Count -ne 1){throw "Condition '$currentId' requires exactly one '$conditionOutcome' edge at runtime; found $($conditionEdges.Count)."}
                $conditionEdge=$conditionEdges[0]
                $targetId=[string]$conditionEdge.toNodeId
                if(-not $nodes.ContainsKey($targetId)){throw "Condition edge '$([string]$conditionEdge.edgeId)' targets missing node '$targetId'."}
                Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When $conditionOutcome -EdgeId ([string]$conditionEdge.edgeId) -ConditionResult $result -Operator ([string]$current.operator) -Event 'ConditionSelected'
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Fork' {
                Start-DynomaxFork -Plan $plan -State $State -ForkNode $current
                $targetId=Start-DynomaxNextForkBranch -State $State
                if(-not $targetId){throw "Fork '$currentId' did not schedule a branch."}
                if(-not $nodes.ContainsKey($targetId)){throw "Fork '$currentId' targets missing node '$targetId'."}
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Join' {
                $targetId=Complete-DynomaxForkBranchAtJoin -Plan $plan -State $State -JoinNodeId $currentId
                if(-not $targetId){throw "Join '$currentId' did not produce a next node."}
                if(-not $nodes.ContainsKey($targetId)){throw "Join '$currentId' targets missing node '$targetId'."}
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Loop' {
                $loopState=Get-DynomaxLoopState -State $State -Node $current
                $started=[DateTimeOffset]::Parse([string]$loopState.startedAtUtc)
                $elapsed=([DateTimeOffset]::UtcNow-$started).TotalSeconds
                if($elapsed -ge [int]$loopState.overallTimeoutSeconds){
                    Fail-DynomaxLoop -State $State -LoopState $loopState -Reason 'OverallTimeoutExceeded'
                    return
                }
                $result=[bool](Test-DynomaxCondition -Node $current -Context $Context)
                if(-not $result){
                    $loopState.completed=$true
                    $loopState.stopReason='ConditionFalse'
                    $loopState.completedAtUtc=[DateTime]::UtcNow.ToString('o')
                    $exitEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq 'False' })
                    if($exitEdges.Count -ne 1){throw "Loop '$currentId' requires exactly one False exit edge."}
                    $edge=$exitEdges[0]
                    $targetId=[string]$edge.toNodeId
                    Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When 'False' -EdgeId ([string]$edge.edgeId) -ConditionResult $false -Operator ([string]$current.operator) -Event 'LoopExit' -LoopIteration ([int]$loopState.iterations)
                    $currentId=$targetId
                    if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                    continue
                }
                if([int]$loopState.iterations -ge [int]$loopState.maximumIterations){
                    Fail-DynomaxLoop -State $State -LoopState $loopState -Reason 'MaximumIterationsExceeded'
                    return
                }
                $loopState.iterations=[int]$loopState.iterations+1
                $bodyEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq 'True' })
                if($bodyEdges.Count -ne 1){throw "Loop '$currentId' requires exactly one True body edge."}
                $edge=$bodyEdges[0]
                $targetId=[string]$edge.toNodeId
                Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When 'True' -EdgeId ([string]$edge.edgeId) -ConditionResult $true -Operator ([string]$current.operator) -Event 'LoopIterationStarted' -LoopIteration ([int]$loopState.iterations)
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Succeed' {
                $State.nextActionNodeId=$null
                $State.terminalNodeId=$currentId
                $State.terminalStatus='PASS'
                return
            }
            'Fail' {
                $State.nextActionNodeId=$null
                $State.terminalNodeId=$currentId
                $State.terminalStatus='FAIL'
                return
            }
            default { throw "Control-flow reached unsupported node type '$([string]$current.type)' at '$currentId'." }
        }
    }
    throw 'Control-flow traversal exceeded the bounded system-node hop count.'
}

function Initialize-DynomaxControlFlowState {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$RunDirectory)
    if(-not (Test-DynomaxControlFlowEnabled -Workflow $Workflow)){return $null}
    $plan=$Workflow.controlFlow
    $schema=[int](Get-DynomaxPropertyValue -Object $plan -Name 'schemaVersion' -DefaultValue 0)
    if($schema -notin @(1,2)){throw "Unsupported controlFlow schemaVersion '$schema'."}
    $startId=[string](Get-DynomaxPropertyValue -Object $plan -Name 'startNodeId' -DefaultValue '')
    if(-not $startId){throw 'controlFlow.startNodeId is required.'}
    $context=Read-DynomaxJson -Path $ContextPath
    $discoveryTarget=Get-DynomaxDiscoveryTargetNodeId -Workflow $Workflow
    $state=[pscustomobject][ordered]@{
        schemaVersion=3
        initializedAtUtc=[DateTime]::UtcNow.ToString('o')
        nextActionNodeId=$null
        terminalNodeId=$null
        terminalStatus=$null
        discoveryTargetNodeId=$discoveryTarget
        discoveryTargetReached=$false
        discoveryBlockReason=$null
        discoveryCompletedAtUtc=$null
        transitions=@()
        executedActionNodeIds=@()
        finalSkippedActionNodeIds=@()
        activeFork=$null
        forkHistory=@()
        loops=@()
    }
    Move-DynomaxControlFlowToNextExecutable -Workflow $Workflow -Context $context -State $state -FromNodeId $startId -Outcome 'Success'
    Write-DynomaxJson -Value $state -Path (Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory)
    return $state
}

function Get-DynomaxControlFlowDecision {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$NodeId)
    if(-not (Test-DynomaxControlFlowEnabled -Workflow $Workflow)){return [pscustomobject]@{ShouldRun=$true;Disposition='RUN';Reason='Static linear workflow.'}}
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){[void](Initialize-DynomaxControlFlowState -Workflow $Workflow -ContextPath $ContextPath -RunDirectory $RunDirectory)}
    $state=Read-DynomaxJson -Path $statePath
    $next=[string](Get-DynomaxPropertyValue -Object $state -Name 'nextActionNodeId' -DefaultValue '')
    $terminal=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
    if($terminal){
        if(@($state.executedActionNodeIds) -contains $NodeId -or @($state.finalSkippedActionNodeIds) -contains $NodeId){
            return [pscustomobject]@{ShouldRun=$false;Disposition='DEFER';Reason="Control flow already completed with terminal status $terminal."}
        }
        $state.finalSkippedActionNodeIds=@($state.finalSkippedActionNodeIds)+@($NodeId)
        Write-DynomaxJson -Value $state -Path $statePath
        return [pscustomobject]@{ShouldRun=$false;Disposition='SKIP_FINAL';Reason="Action was not selected before terminal status $terminal."}
    }
    if($next -eq $NodeId){return [pscustomobject]@{ShouldRun=$true;Disposition='RUN';Reason='Selected by control flow.'}}
    return [pscustomobject]@{ShouldRun=$false;Disposition='DEFER';Reason=$(if($next){"Control flow currently selected '$next'."}else{'Control flow has not selected an Action yet.'})}
}

function Complete-DynomaxControlFlowAction {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$NodeId)
    if(-not (Test-DynomaxControlFlowEnabled -Workflow $Workflow)){return $null}
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){throw 'Control-flow state is missing.'}
    $state=Read-DynomaxJson -Path $statePath
    $next=[string](Get-DynomaxPropertyValue -Object $state -Name 'nextActionNodeId' -DefaultValue '')
    if($next -ne $NodeId){throw "Action '$NodeId' completed but control flow expected '$next'."}
    if(-(@($state.executedActionNodeIds) -contains $NodeId)){$state.executedActionNodeIds=@($state.executedActionNodeIds)+@($NodeId)}
    $discoveryTarget=Get-DynomaxDiscoveryTargetNodeId -Workflow $Workflow
    if($discoveryTarget -and $NodeId -eq $discoveryTarget){
        $state.nextActionNodeId=$null
        $state.terminalNodeId=$NodeId
        $state.terminalStatus='PASS'
        $state.discoveryTargetReached=$true
        $state.discoveryBlockReason=$null
        $state.discoveryCompletedAtUtc=[DateTime]::UtcNow.ToString('o')
        Write-DynomaxJson -Value $state -Path $statePath
        return $state
    }
    $context=Read-DynomaxJson -Path $ContextPath
    Move-DynomaxControlFlowToNextExecutable -Workflow $Workflow -Context $context -State $state -FromNodeId $NodeId -Outcome 'Success'
    Write-DynomaxJson -Value $state -Path $statePath
    return $state
}

function Fail-DynomaxControlFlowAction {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$NodeId)
    if(-not (Test-DynomaxControlFlowEnabled -Workflow $Workflow)){return $null}
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){throw 'Control-flow state is missing.'}
    $state=Read-DynomaxJson -Path $statePath
    if(-(@($state.executedActionNodeIds) -contains $NodeId)){$state.executedActionNodeIds=@($state.executedActionNodeIds)+@($NodeId)}
    $state.nextActionNodeId=$null
    $state.terminalNodeId=$NodeId
    $state.terminalStatus='FAIL'
    Add-DynomaxControlFlowTransition -State $state -FromNodeId $NodeId -ToNodeId $NodeId -When 'Failure' -EdgeId '' -Event 'ActionFailed'
    Write-DynomaxJson -Value $state -Path $statePath
    return $state
}

function Assert-DynomaxDiscoveryTargetReached {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][string]$RunDirectory)
    $target=Get-DynomaxDiscoveryTargetNodeId -Workflow $Workflow
    if(-not $target){return $true}
    if(-not (Test-DynomaxControlFlowEnabled -Workflow $Workflow)){return $true}
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){throw "Branch-aware Discovery target '$target' has no control-flow state evidence."}
    $state=Read-DynomaxJson -Path $statePath
    $recorded=[string](Get-DynomaxPropertyValue -Object $state -Name 'discoveryTargetNodeId' -DefaultValue '')
    $reached=[bool](Get-DynomaxPropertyValue -Object $state -Name 'discoveryTargetReached' -DefaultValue $false)
    if($recorded -ne $target -or -not $reached){
        $reason=[string](Get-DynomaxPropertyValue -Object $state -Name 'discoveryBlockReason' -DefaultValue '')
        if(-not $reason){$reason='The actual runtime-selected control-flow state did not reach the requested Action.'}
        throw "Branch-aware Discovery target '$target' was not reached. $reason"
    }
    return $true
}
