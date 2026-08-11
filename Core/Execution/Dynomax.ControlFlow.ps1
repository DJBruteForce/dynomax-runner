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
            $nodeId=[string](Get-DynomaxPropertyValue -Object $Binding -Name 'nodeId' -DefaultValue '')
            $output=[string](Get-DynomaxPropertyValue -Object $Binding -Name 'outputName' -DefaultValue '')
            if(-not $output){throw 'Control-flow NodeOutput binding has no outputName.'}
            $pool=Get-DynomaxPropertyValue -Object $Context -Name 'runDataPool' -DefaultValue $null
            $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
            if($nodeId -and $null -ne $steps){
                $matches=@()
                foreach($stepProperty in @($steps.PSObject.Properties)){
                    $step=$stepProperty.Value
                    if([string](Get-DynomaxPropertyValue -Object $step -Name 'workflowNodeId' -DefaultValue '') -ne $nodeId){continue}
                    $outputs=Get-DynomaxPropertyValue -Object $step -Name 'outputs' -DefaultValue $null
                    $outputProperty=if($null -ne $outputs){$outputs.PSObject.Properties[$output]}else{$null}
                    if($null -ne $outputProperty -and [bool](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'available' -DefaultValue $false)){
                        $matches+=,[pscustomobject]@{executionSlot=[int](Get-DynomaxPropertyValue -Object $step -Name 'executionSlot' -DefaultValue 1);capturedAtUtc=[string](Get-DynomaxPropertyValue -Object $step -Name 'capturedAtUtc' -DefaultValue '');value=(Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'value' -DefaultValue $null)}
                    }
                }
                $selected=@($matches|Sort-Object executionSlot,capturedAtUtc -Descending|Select-Object -First 1)
                if($selected.Count -eq 1){return $selected[0].value}
            }
            # Compatibility fallback for historical context seeds/publications that predate Run Data Pool capture.
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

function Get-DynomaxSystemNodeState {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$NodeId)
    $matches=@($State.systemNodeStates | Where-Object { [string]$_.nodeId -eq $NodeId })
    if($matches.Count -ne 1){throw "Control-flow System node '$NodeId' has no unique runtime state."}
    return $matches[0]
}

function Set-DynomaxSystemNodeState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$NodeId,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Event,
        [string]$Message,
        [string]$BranchLabel,
        [Nullable[int]]$BranchIndex=$null,
        [Nullable[int]]$LoopIteration=$null,
        [string]$StopReason
    )
    $nodeState=Get-DynomaxSystemNodeState -State $State -NodeId $NodeId
    $now=[DateTime]::UtcNow.ToString('o')
    if($Status -eq 'Running' -and -not $nodeState.startedAtUtc){$nodeState.startedAtUtc=$now}
    if($Status -in @('PASS','FAIL','SKIPPED')){
        if(-not $nodeState.startedAtUtc -and $Status -ne 'SKIPPED'){$nodeState.startedAtUtc=$now}
        $nodeState.completedAtUtc=$now
    }
    $nodeState.status=$Status
    $nodeState.lastEvent=$Event
    $nodeState.message=$Message
    $eventData=[ordered]@{
        sequence=(@($State.systemNodeEvents).Count + 1)
        atUtc=$now
        nodeId=$NodeId
        nodeType=[string]$nodeState.nodeType
        status=$Status
        event=$Event
    }
    if($Message){$eventData.message=$Message}
    if($BranchLabel){$eventData.branchLabel=$BranchLabel}
    if($null -ne $BranchIndex){$eventData.branchIndex=[int]$BranchIndex}
    if($null -ne $LoopIteration){$eventData.loopIteration=[int]$LoopIteration}
    if($StopReason){$eventData.stopReason=$StopReason}
    $State.systemNodeEvents=@($State.systemNodeEvents)+@([pscustomobject]$eventData)
}

function Finalize-DynomaxPendingSystemNodes {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State)
    foreach($nodeState in @($State.systemNodeStates | Where-Object { [string]$_.status -eq 'Pending' })){
        Set-DynomaxSystemNodeState -State $State -NodeId ([string]$nodeState.nodeId) -Status 'SKIPPED' -Event 'SystemNodeSkipped' -Message 'The System node was not selected before Workflow termination.'
    }
}

function Get-DynomaxControlFlowRunEventId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$Stream,
        [Parameter(Mandatory)][int]$Sequence
    )
    $text=('{0:D}|{1}|{2}' -f $RunId,$Stream,$Sequence)
    $bytes=[System.Text.Encoding]::UTF8.GetBytes($text)
    $sha=[System.Security.Cryptography.SHA256]::Create()
    try{$hash=$sha.ComputeHash($bytes)}finally{$sha.Dispose()}
    $guidBytes=New-Object byte[] 16
    [Array]::Copy($hash,0,$guidBytes,0,16)
    return New-Object -TypeName System.Guid -ArgumentList (,$guidBytes)
}

function Sync-DynomaxControlFlowRunEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$RunDirectory,
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    $statePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
    if(-not(Test-Path -LiteralPath $statePath -PathType Leaf)){return}
    $state=Read-DynomaxJson -Path $statePath
    $systemEvents=@((Get-DynomaxPropertyValue -Object $state -Name 'systemNodeEvents' -DefaultValue @()))
    $systemCursor=[int](Get-DynomaxPropertyValue -Object $state -Name 'persistedSystemNodeEventCount' -DefaultValue 0)
    for($i=$systemCursor;$i -lt $systemEvents.Count;$i++){
        $item=$systemEvents[$i]
        $nodeId=[string](Get-DynomaxPropertyValue -Object $item -Name 'nodeId' -DefaultValue '')
        $nodeType=[string](Get-DynomaxPropertyValue -Object $item -Name 'nodeType' -DefaultValue '')
        $status=[string](Get-DynomaxPropertyValue -Object $item -Name 'status' -DefaultValue '')
        $event=[string](Get-DynomaxPropertyValue -Object $item -Name 'event' -DefaultValue '')
        $message=[string](Get-DynomaxPropertyValue -Object $item -Name 'message' -DefaultValue '')
        if(-not $message){$message="$nodeType '$nodeId' -> $status ($event)."}
        $level=if($status -eq 'FAIL'){'Error'}elseif($status -eq 'SKIPPED'){'Info'}else{'Info'}
        $eventId=Get-DynomaxControlFlowRunEventId -RunId $RunId -Stream 'SystemNodeState' -Sequence ([int](Get-DynomaxPropertyValue -Object $item -Name 'sequence' -DefaultValue ($i+1)))
        Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel $level -EventType 'ControlFlow.SystemNodeState' -Message $message -Data $item -RunEventId $eventId -Connection $Connection
    }
    $transitions=@((Get-DynomaxPropertyValue -Object $state -Name 'transitions' -DefaultValue @()))
    $transitionCursor=[int](Get-DynomaxPropertyValue -Object $state -Name 'persistedTransitionCount' -DefaultValue 0)
    for($i=$transitionCursor;$i -lt $transitions.Count;$i++){
        $item=$transitions[$i]
        $from=[string](Get-DynomaxPropertyValue -Object $item -Name 'fromNodeId' -DefaultValue '')
        $to=[string](Get-DynomaxPropertyValue -Object $item -Name 'toNodeId' -DefaultValue '')
        $event=[string](Get-DynomaxPropertyValue -Object $item -Name 'event' -DefaultValue '')
        $message=if($event){"Control-flow transition '$event': '$from' -> '$to'."}else{"Control-flow transition: '$from' -> '$to'."}
        $eventId=Get-DynomaxControlFlowRunEventId -RunId $RunId -Stream 'Transition' -Sequence ([int](Get-DynomaxPropertyValue -Object $item -Name 'sequence' -DefaultValue ($i+1)))
        Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'ControlFlow.Transition' -Message $message -Data $item -RunEventId $eventId -Connection $Connection
    }
    $state.persistedSystemNodeEventCount=$systemEvents.Count
    $state.persistedTransitionCount=$transitions.Count
    Write-DynomaxJson -Value $state -Path $statePath
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
        kind='Loop'
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
    Set-DynomaxSystemNodeState -State $State -NodeId ([string]$LoopState.nodeId) -Status 'FAIL' -Event 'LoopFailed' -Message "Bounded Loop failed closed: $Reason." -LoopIteration ([int]$LoopState.iterations) -StopReason $Reason
    Add-DynomaxControlFlowTransition -State $State -FromNodeId ([string]$LoopState.nodeId) -ToNodeId ([string]$LoopState.nodeId) -When 'Failure' -EdgeId '' -Event 'LoopFailed' -LoopIteration ([int]$LoopState.iterations)
    Finalize-DynomaxPendingSystemNodes -State $State
}

function Get-DynomaxRepeatState {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State,[Parameter(Mandatory)]$Node)
    $nodeId=[string]$Node.nodeId
    foreach($existing in @($State.loops)){
        if([string]$existing.nodeId -eq $nodeId){return $existing}
    }
    $created=[pscustomobject][ordered]@{
        nodeId=$nodeId
        kind='Repeat'
        startedAtUtc=[DateTime]::UtcNow.ToString('o')
        maximumIterations=[int](Get-DynomaxPropertyValue -Object $Node -Name 'count' -DefaultValue 0)
        overallTimeoutSeconds=[int](Get-DynomaxPropertyValue -Object $Node -Name 'overallTimeoutSeconds' -DefaultValue 0)
        iterations=0
        completed=$false
        stopReason=$null
        completedAtUtc=$null
    }
    $State.loops=@($State.loops)+@($created)
    return $created
}

function Fail-DynomaxRepeat {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$State,[Parameter(Mandatory)]$RepeatState,[Parameter(Mandatory)][string]$Reason)
    $RepeatState.completed=$true
    $RepeatState.stopReason=$Reason
    $RepeatState.completedAtUtc=[DateTime]::UtcNow.ToString('o')
    $State.nextActionNodeId=$null
    $State.terminalNodeId=[string]$RepeatState.nodeId
    $State.terminalStatus='FAIL'
    Set-DynomaxSystemNodeState -State $State -NodeId ([string]$RepeatState.nodeId) -Status 'FAIL' -Event 'RepeatFailed' -Message "Repeat N Times failed closed: $Reason." -LoopIteration ([int]$RepeatState.iterations) -StopReason $Reason
    Add-DynomaxControlFlowTransition -State $State -FromNodeId ([string]$RepeatState.nodeId) -ToNodeId ([string]$RepeatState.nodeId) -When 'Failure' -EdgeId '' -Event 'RepeatFailed' -LoopIteration ([int]$RepeatState.iterations)
    Finalize-DynomaxPendingSystemNodes -State $State
}

function Get-DynomaxSwitchTarget {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$Node,[Parameter(Mandatory)]$Context)
    $nodeId=[string]$Node.nodeId
    $binding=Get-DynomaxPropertyValue -Object $Node -Name 'value' -DefaultValue $null
    if($null -eq $binding){throw "Switch '$nodeId' has no value binding."}
    $value=Get-DynomaxControlFlowContextValue -Context $Context -Binding $binding
    $candidate=if($null -eq $value){'null'}elseif($value -is [bool]){if([bool]$value){'true'}else{'false'}}else{[Convert]::ToString($value,[Globalization.CultureInfo]::InvariantCulture)}
    $caseSensitive=[bool](Get-DynomaxPropertyValue -Object $Node -Name 'caseSensitive' -DefaultValue $true)
    $comparison=if($caseSensitive){[StringComparison]::Ordinal}else{[StringComparison]::OrdinalIgnoreCase}
    $branches=@(Get-DynomaxControlFlowOutgoing -Plan $Plan -NodeId $nodeId | Where-Object { [string]$_.when -eq 'Branch' })
    $default=$null
    foreach($edge in $branches){
        $label=[string](Get-DynomaxPropertyValue -Object $edge -Name 'label' -DefaultValue '')
        if([string]::Equals($label,'Default',[StringComparison]::OrdinalIgnoreCase)){$default=$edge;continue}
        if([string]::Equals($label,$candidate,$comparison)){return $edge}
    }
    return $default
}

function Complete-DynomaxLoopJump {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$State,[Parameter(Mandatory)]$Node,[Parameter(Mandatory)][ValidateSet('Break','Continue')]$Kind)
    $nodeId=[string]$Node.nodeId
    $edges=@(Get-DynomaxControlFlowOutgoing -Plan $Plan -NodeId $nodeId | Where-Object { [string]$_.when -eq 'Success' })
    if($edges.Count -ne 1){throw "$Kind Loop '$nodeId' requires exactly one Success edge."}
    $edge=$edges[0]
    $targetId=[string]$edge.toNodeId
    $active=@($State.loops | Where-Object { -not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'completed' -DefaultValue $false) })
    [array]::Reverse($active)
    $matched=$null
    foreach($scope in $active){
        $scopeNodeId=[string](Get-DynomaxPropertyValue -Object $scope -Name 'nodeId' -DefaultValue '')
        if(-not $scopeNodeId){continue}
        if($Kind -eq 'Break'){
            $exit=@((Get-DynomaxControlFlowOutgoing -Plan $Plan -NodeId $scopeNodeId) | Where-Object { [string]$_.when -eq 'False' })
            if($exit.Count -eq 1 -and [string]$exit[0].toNodeId -eq $targetId){$matched=$scope;break}
            continue
        }

        $scopeNode=Get-DynomaxControlFlowNode -Plan $Plan -NodeId $scopeNodeId
        if($null -eq $scopeNode){continue}
        $scopeKind=[string](Get-DynomaxPropertyValue -Object $scope -Name 'kind' -DefaultValue '')
        $expectedTarget=$scopeNodeId
        if($scopeKind -eq 'Loop'){
            $left=Get-DynomaxPropertyValue -Object $scopeNode -Name 'left' -DefaultValue $null
            $expectedTarget=[string](Get-DynomaxPropertyValue -Object $left -Name 'sourceNodeId' -DefaultValue '')
        }
        if($expectedTarget -and $expectedTarget -eq $targetId){$matched=$scope;break}
    }
    if($null -eq $matched){throw "$Kind Loop '$nodeId' has no active enclosing bounded loop matching its validated jump target."}
    if($Kind -eq 'Break'){
        $matched.completed=$true
        $matched.stopReason='Break'
        $matched.completedAtUtc=[DateTime]::UtcNow.ToString('o')
        Set-DynomaxSystemNodeState -State $State -NodeId ([string]$matched.nodeId) -Status 'PASS' -Event 'LoopBroken' -Message 'The active bounded loop exited through Break Loop.' -LoopIteration ([int]$matched.iterations) -StopReason 'Break'
    }
    Set-DynomaxSystemNodeState -State $State -NodeId $nodeId -Status 'PASS' -Event $(if($Kind -eq 'Break'){'LoopBreak'}else{'LoopContinue'}) -Message $(if($Kind -eq 'Break'){'Break Loop selected the enclosing loop exit.'}else{'Continue Loop selected the enclosing loop next-iteration boundary.'})
    Add-DynomaxControlFlowTransition -State $State -FromNodeId $nodeId -ToNodeId $targetId -When 'Success' -EdgeId ([string]$edge.edgeId) -Event $(if($Kind -eq 'Break'){'LoopBreak'}else{'LoopContinue'})
    return $targetId
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
    Set-DynomaxSystemNodeState -State $State -NodeId $forkId -Status 'Running' -Event 'ForkStarted' -Message 'Fork began deterministic FailFast branch scheduling.'
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

function Stop-DynomaxActiveForkFailFast {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$FailedNodeId,
        [Parameter(Mandatory)][string]$FailureMessage
    )
    $fork=Get-DynomaxPropertyValue -Object $State -Name 'activeFork' -DefaultValue $null
    if($null -eq $fork){return}
    $currentIndex=[int](Get-DynomaxPropertyValue -Object $fork -Name 'currentBranchIndex' -DefaultValue -1)
    foreach($branch in @($fork.branches)){
        if([int]$branch.index -eq $currentIndex -and [string]$branch.status -eq 'Running'){
            $branch.status='Failed';$branch.completedAtUtc=[DateTime]::UtcNow.ToString('o')
            Add-DynomaxControlFlowTransition -State $State -FromNodeId ([string]$fork.forkNodeId) -ToNodeId ([string]$branch.targetNodeId) -When 'Failure' -EdgeId ([string]$branch.edgeId) -Event 'ForkBranchFailed' -BranchLabel ([string]$branch.label) -BranchIndex ([int]$branch.index)
        }elseif([string]$branch.status -eq 'Pending'){
            $branch.status='Skipped';$branch.completedAtUtc=[DateTime]::UtcNow.ToString('o')
            Add-DynomaxControlFlowTransition -State $State -FromNodeId ([string]$fork.forkNodeId) -ToNodeId ([string]$branch.targetNodeId) -When 'Branch' -EdgeId ([string]$branch.edgeId) -Event 'ForkBranchSkippedFailFast' -BranchLabel ([string]$branch.label) -BranchIndex ([int]$branch.index)
        }
    }
    $fork.completedAtUtc=[DateTime]::UtcNow.ToString('o')
    $forkState=Get-DynomaxSystemNodeState -State $State -NodeId ([string]$fork.forkNodeId)
    if([string]$forkState.status -ne 'FAIL'){
        Set-DynomaxSystemNodeState -State $State -NodeId ([string]$fork.forkNodeId) -Status 'FAIL' -Event 'ForkFailedFast' -Message $FailureMessage
    }
    $joinId=[string](Get-DynomaxPropertyValue -Object $fork -Name 'joinNodeId' -DefaultValue '')
    if($joinId){
        $joinState=Get-DynomaxSystemNodeState -State $State -NodeId $joinId
        if([string]$joinState.status -notin @('FAIL','PASS','SKIPPED')){
            Set-DynomaxSystemNodeState -State $State -NodeId $joinId -Status 'SKIPPED' -Event 'JoinSkippedFailFast' -Message 'Join All was not released because the paired Fork failed fast.'
        }
    }
    $State.forkHistory=@($State.forkHistory)+@($fork)
    $State.activeFork=$null
}

function Fail-DynomaxSystemNodeExecution {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$NodeId
    )
    $nodeState=Get-DynomaxSystemNodeState -State $State -NodeId $NodeId
    $nodeType=[string]$nodeState.nodeType
    $safeMessage="$nodeType '$NodeId' failed during control-flow evaluation. Compared runtime operand values were not persisted."
    if([string]$nodeState.status -ne 'FAIL'){
        Set-DynomaxSystemNodeState -State $State -NodeId $NodeId -Status 'FAIL' -Event 'SystemNodeFailed' -Message $safeMessage
    }
    Stop-DynomaxActiveForkFailFast -State $State -FailedNodeId $NodeId -FailureMessage "Fork failed fast because System node '$NodeId' failed."
    $State.nextActionNodeId=$null
    $State.terminalNodeId=$NodeId
    $State.terminalStatus='FAIL'
    Add-DynomaxControlFlowTransition -State $State -FromNodeId $NodeId -ToNodeId $NodeId -When 'Failure' -EdgeId '' -Event 'SystemNodeFailed'
    Finalize-DynomaxPendingSystemNodes -State $State
}

function Complete-DynomaxForkBranchAtJoin {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Plan,[Parameter(Mandatory)]$State,[Parameter(Mandatory)][string]$JoinNodeId)
    $fork=$State.activeFork
    if($null -eq $fork -or [string]$fork.joinNodeId -ne $JoinNodeId){throw "Join '$JoinNodeId' was reached without its active Fork."}
    $currentIndex=[int]$fork.currentBranchIndex
    $current=@($fork.branches | Where-Object { [int]$_.index -eq $currentIndex })
    if($current.Count -ne 1){throw "Fork '$([string]$fork.forkNodeId)' has no active branch at Join '$JoinNodeId'."}
    if([string]((Get-DynomaxSystemNodeState -State $State -NodeId $JoinNodeId).status) -eq 'Pending'){
        Set-DynomaxSystemNodeState -State $State -NodeId $JoinNodeId -Status 'Running' -Event 'JoinWaiting' -Message 'Join All is waiting for all scheduled sibling branches.'
    }
    $current[0].status='Completed'
    $current[0].completedAtUtc=[DateTime]::UtcNow.ToString('o')
    Add-DynomaxControlFlowTransition -State $State -FromNodeId ([string]$fork.forkNodeId) -ToNodeId $JoinNodeId -When 'Branch' -EdgeId ([string]$current[0].edgeId) -Event 'ForkBranchCompleted' -BranchLabel ([string]$current[0].label) -BranchIndex ([int]$current[0].index)
    $next=Start-DynomaxNextForkBranch -State $State
    if($next){return $next}

    $fork.completedAtUtc=[DateTime]::UtcNow.ToString('o')
    Set-DynomaxSystemNodeState -State $State -NodeId ([string]$fork.forkNodeId) -Status 'PASS' -Event 'ForkCompleted' -Message 'All Fork branches completed successfully.'
    Set-DynomaxSystemNodeState -State $State -NodeId $JoinNodeId -Status 'PASS' -Event 'JoinCompleted' -Message 'Join All released after every scheduled sibling branch completed.'
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
        try{
            switch([string]$current.type){
            'Action' {
                $State.nextActionNodeId=$currentId
                $State.terminalNodeId=$null
                $State.terminalStatus=$null
                return
            }
            'Condition' {
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'Running' -Event 'ConditionEvaluating' -Message 'Condition is evaluating its configured typed operands.'
                $result=[bool](Test-DynomaxCondition -Node $current -Context $Context)
                $conditionOutcome=if($result){'True'}else{'False'}
                $conditionEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq $conditionOutcome })
                if($conditionEdges.Count -ne 1){throw "Condition '$currentId' requires exactly one '$conditionOutcome' edge at runtime; found $($conditionEdges.Count)."}
                $conditionEdge=$conditionEdges[0]
                $targetId=[string]$conditionEdge.toNodeId
                if(-not $nodes.ContainsKey($targetId)){throw "Condition edge '$([string]$conditionEdge.edgeId)' targets missing node '$targetId'."}
                Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When $conditionOutcome -EdgeId ([string]$conditionEdge.edgeId) -ConditionResult $result -Operator ([string]$current.operator) -Event 'ConditionSelected'
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'PASS' -Event 'ConditionSelected' -Message "Condition selected the '$conditionOutcome' edge."
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Switch' {
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'Running' -Event 'SwitchEvaluating' -Message 'Switch / Case is evaluating its configured typed value.'
                $caseEdge=Get-DynomaxSwitchTarget -Plan $plan -Node $current -Context $Context
                if($null -eq $caseEdge){throw "Switch '$currentId' matched no case and has no Default path."}
                $targetId=[string]$caseEdge.toNodeId
                if(-not $nodes.ContainsKey($targetId)){throw "Switch case edge '$([string]$caseEdge.edgeId)' targets missing node '$targetId'."}
                Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When 'Branch' -EdgeId ([string]$caseEdge.edgeId) -Event 'SwitchCaseSelected' -BranchLabel ([string]$caseEdge.label)
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'PASS' -Event 'SwitchCaseSelected' -Message "Switch selected case '$([string]$caseEdge.label)'." -BranchLabel ([string]$caseEdge.label)
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Assert' {
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'Running' -Event 'AssertEvaluating' -Message 'Assert is evaluating its configured typed operands.'
                $result=[bool](Test-DynomaxCondition -Node $current -Context $Context)
                if(-not $result){
                    $classification=[string](Get-DynomaxPropertyValue -Object $current -Name 'classification' -DefaultValue 'ASSERTION_FAILED')
                    $message=[string](Get-DynomaxPropertyValue -Object $current -Name 'message' -DefaultValue 'Assertion failed.')
                    $State.nextActionNodeId=$null
                    $State.terminalNodeId=$currentId
                    $State.terminalStatus='FAIL'
                    Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'FAIL' -Event 'AssertionFailed' -Message $(if($message){$message}else{'Assertion failed.'}) -StopReason $(if($classification){$classification}else{'ASSERTION_FAILED'})
                    Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $currentId -When 'Failure' -EdgeId '' -ConditionResult $false -Operator ([string]$current.operator) -Event 'AssertionFailed'
                    Finalize-DynomaxPendingSystemNodes -State $State
                    return
                }
                $successEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq 'Success' })
                if($successEdges.Count -ne 1){throw "Assert '$currentId' requires exactly one Success edge."}
                $edge=$successEdges[0]
                $targetId=[string]$edge.toNodeId
                Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When 'Success' -EdgeId ([string]$edge.edgeId) -ConditionResult $true -Operator ([string]$current.operator) -Event 'AssertionPassed'
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'PASS' -Event 'AssertionPassed' -Message 'Assert condition passed.'
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
                if([string]((Get-DynomaxSystemNodeState -State $State -NodeId $currentId).status) -eq 'Pending'){
                    Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'Running' -Event 'LoopStarted' -Message 'Bounded Loop evaluation started.' -LoopIteration ([int]$loopState.iterations)
                }
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
                    Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'PASS' -Event 'LoopExited' -Message 'Bounded Loop exited because its condition evaluated False.' -LoopIteration ([int]$loopState.iterations) -StopReason 'ConditionFalse'
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
            'Repeat' {
                $repeatState=Get-DynomaxRepeatState -State $State -Node $current
                if([string]((Get-DynomaxSystemNodeState -State $State -NodeId $currentId).status) -eq 'Pending'){
                    Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'Running' -Event 'RepeatStarted' -Message 'Repeat N Times started.' -LoopIteration ([int]$repeatState.iterations)
                }
                $started=[DateTimeOffset]::Parse([string]$repeatState.startedAtUtc)
                if((([DateTimeOffset]::UtcNow-$started).TotalSeconds) -ge [int]$repeatState.overallTimeoutSeconds){
                    Fail-DynomaxRepeat -State $State -RepeatState $repeatState -Reason 'OverallTimeoutExceeded'
                    return
                }
                if([int]$repeatState.iterations -ge [int]$repeatState.maximumIterations){
                    $repeatState.completed=$true
                    $repeatState.stopReason='CountCompleted'
                    $repeatState.completedAtUtc=[DateTime]::UtcNow.ToString('o')
                    $exitEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq 'False' })
                    if($exitEdges.Count -ne 1){throw "Repeat '$currentId' requires exactly one False exit edge."}
                    $edge=$exitEdges[0]
                    $targetId=[string]$edge.toNodeId
                    Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When 'False' -EdgeId ([string]$edge.edgeId) -Event 'RepeatCompleted' -LoopIteration ([int]$repeatState.iterations)
                    Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'PASS' -Event 'RepeatCompleted' -Message 'Repeat N Times completed its configured count.' -LoopIteration ([int]$repeatState.iterations) -StopReason 'CountCompleted'
                    $currentId=$targetId
                    if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                    continue
                }
                $repeatState.iterations=[int]$repeatState.iterations+1
                $bodyEdges=@(Get-DynomaxControlFlowOutgoing -Plan $plan -NodeId $currentId | Where-Object { [string]$_.when -eq 'True' })
                if($bodyEdges.Count -ne 1){throw "Repeat '$currentId' requires exactly one True body edge."}
                $edge=$bodyEdges[0]
                $targetId=[string]$edge.toNodeId
                Add-DynomaxControlFlowTransition -State $State -FromNodeId $currentId -ToNodeId $targetId -When 'True' -EdgeId ([string]$edge.edgeId) -Event 'RepeatIterationStarted' -LoopIteration ([int]$repeatState.iterations)
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Break' {
                $targetId=Complete-DynomaxLoopJump -Plan $plan -State $State -Node $current -Kind 'Break'
                if(-not $nodes.ContainsKey($targetId)){throw "Break Loop '$currentId' targets missing node '$targetId'."}
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Continue' {
                $targetId=Complete-DynomaxLoopJump -Plan $plan -State $State -Node $current -Kind 'Continue'
                if(-not $nodes.ContainsKey($targetId)){throw "Continue Loop '$currentId' targets missing node '$targetId'."}
                $currentId=$targetId
                if(-not(Test-DynomaxDiscoveryAfterMove -Workflow $Workflow -State $State -CurrentNodeId $currentId)){return}
                continue
            }
            'Succeed' {
                $State.nextActionNodeId=$null
                $State.terminalNodeId=$currentId
                $State.terminalStatus='PASS'
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'PASS' -Event 'WorkflowSucceeded' -Message 'Workflow reached End successfully.'
                Finalize-DynomaxPendingSystemNodes -State $State
                return
            }
            'Fail' {
                $State.nextActionNodeId=$null
                $State.terminalNodeId=$currentId
                $State.terminalStatus='FAIL'
                Set-DynomaxSystemNodeState -State $State -NodeId $currentId -Status 'FAIL' -Event 'WorkflowFailed' -Message 'Workflow reached End with failure.'
                Finalize-DynomaxPendingSystemNodes -State $State
                return
            }
                default { throw "Control-flow reached unsupported node type '$([string]$current.type)' at '$currentId'." }
            }
        }
        catch{
            if([string]$current.type -ne 'Action'){
                Fail-DynomaxSystemNodeExecution -State $State -NodeId $currentId
                return
            }
            throw
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
    if($schema -notin @(1,2,3)){throw "Unsupported controlFlow schemaVersion '$schema'."}
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
        systemNodeStates=@($plan.nodes | Where-Object { [string]$_.type -ne 'Action' } | ForEach-Object {
            [pscustomobject][ordered]@{nodeId=[string]$_.nodeId;nodeType=[string]$_.type;status='Pending';startedAtUtc=$null;completedAtUtc=$null;lastEvent=$null;message=$null}
        })
        systemNodeEvents=@()
        persistedSystemNodeEventCount=0
        persistedTransitionCount=0
    }
    foreach($systemNodeState in @($state.systemNodeStates)){
        Set-DynomaxSystemNodeState -State $state -NodeId ([string]$systemNodeState.nodeId) -Status 'Pending' -Event 'SystemNodePending' -Message 'System node is waiting for the runtime-selected control-flow path.'
    }
    Set-DynomaxSystemNodeState -State $state -NodeId $startId -Status 'PASS' -Event 'WorkflowStarted' -Message 'Workflow control flow started.'
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
        # Once Workflow control flow is terminal there is no future scheduling decision to defer to.
        # A later physical occurrence of an already-executed logical Action is still a final skip for
        # that physical slot; returning DEFER here caused large pre-unrolled Loop suites to drain
        # hundreds of redundant control-flow subprocesses after the Loop had already failed/passed.
        if(-not(@($state.executedActionNodeIds) -contains $NodeId) -and -not(@($state.finalSkippedActionNodeIds) -contains $NodeId)){
            $state.finalSkippedActionNodeIds=@($state.finalSkippedActionNodeIds)+@($NodeId)
            Write-DynomaxJson -Value $state -Path $statePath
        }
        return [pscustomobject]@{ShouldRun=$false;Disposition='SKIP_FINAL';Reason="Workflow control flow already completed with terminal status $terminal."}
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
        Finalize-DynomaxPendingSystemNodes -State $state
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
    Stop-DynomaxActiveForkFailFast -State $state -FailedNodeId $NodeId -FailureMessage "Fork failed fast because Action '$NodeId' failed."
    $state.nextActionNodeId=$null
    $state.terminalNodeId=$NodeId
    $state.terminalStatus='FAIL'
    Add-DynomaxControlFlowTransition -State $state -FromNodeId $NodeId -ToNodeId $NodeId -When 'Failure' -EdgeId '' -Event 'ActionFailed'
    Finalize-DynomaxPendingSystemNodes -State $state
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
