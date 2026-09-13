[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][string]$WorkflowPath,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][Guid]$RunId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $DynomaxRoot 'Core\Results\Dynomax.Results.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ExecutionPolicy.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ControlFlow.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Orchestration.ps1')

$config=Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
$workflow=Read-DynomaxJson -Path $WorkflowPath
$connection=$null
$persistedContextCache=@{}
$controlFlowState=$null
$controlFlowDirty=$false
$controlFlowMutationCount=0
$controlFlowCheckpointInterval=25
$controlFlowStatePath=Get-DynomaxControlFlowStatePath -RunDirectory $RunDirectory
if(Test-DynomaxControlFlowEnabled -Workflow $workflow){
    if(-not(Test-Path -LiteralPath $controlFlowStatePath -PathType Leaf)){
        [void](Initialize-DynomaxControlFlowState -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory)
    }
    $controlFlowState=Read-DynomaxJson -Path $controlFlowStatePath
}

function Get-DynomaxHostConnection {
    if($null -eq $script:connection -or $script:connection.State -in @([System.Data.ConnectionState]::Closed,[System.Data.ConnectionState]::Broken)){
        if($null -ne $script:connection){try{$script:connection.Dispose()}catch{};$script:connection=$null}
        $script:connection=Open-DynomaxConnection -SqlConfig $script:sqlConfig
    }
    return $script:connection
}


function Save-DynomaxHostControlFlowCheckpoint {
    param([switch]$Force)
    if($null -eq $script:controlFlowState -or -not $script:controlFlowDirty){return}
    if(-not $Force -and ($script:controlFlowMutationCount % $script:controlFlowCheckpointInterval) -ne 0){return}
    $activeConnection=Get-DynomaxHostConnection
    # Persist all new System-node and transition evidence in one bounded SQL batch before the
    # matching state cursors are checkpointed. Any failure leaves the dirty state intact so the
    # deterministic event ids are retried safely at the next forced checkpoint.
    [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $script:sqlConfig -RunId $RunId -RunDirectory $RunDirectory -Connection $activeConnection -State $script:controlFlowState -SkipStateWrite)
    Write-DynomaxJson -Value $script:controlFlowState -Path $script:controlFlowStatePath
    $script:controlFlowDirty=$false
}

function Write-DynomaxHostResponse {
    param([Parameter(Mandatory)]$Response)
    [Console]::Out.WriteLine(($Response|ConvertTo-Json -Depth 100 -Compress))
    [Console]::Out.Flush()
}

try{
    $connection=Open-DynomaxConnection -SqlConfig $sqlConfig
    while($true){
        $line=[Console]::In.ReadLine()
        if($null -eq $line){break}
        if([string]::IsNullOrWhiteSpace($line)){continue}
        $requestId=$null
        try{
            $request=$line|ConvertFrom-Json
            $requestId=[string](Get-DynomaxPropertyValue -Object $request -Name 'id' -DefaultValue '')
            $operation=[string](Get-DynomaxPropertyValue -Object $request -Name 'operation' -DefaultValue '')
            $args=Get-DynomaxPropertyValue -Object $request -Name 'arguments' -DefaultValue ([pscustomobject]@{})
            if($operation -eq 'Shutdown'){
                Save-DynomaxHostControlFlowCheckpoint -Force
                Write-DynomaxHostResponse -Response ([ordered]@{id=$requestId;ok=$true;result='OK'})
                break
            }
            $activeConnection=Get-DynomaxHostConnection
            switch($operation){
                'Ping' { $result='OK' }
                'ControlFlow' {
                    $mode=[string]$args.mode
                    $result=Invoke-DynomaxControlFlowOperation -Mode $mode -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -RunId $RunId -NodeId ([string]$args.nodeId) -SqlConfig $sqlConfig -Connection $activeConnection -State $controlFlowState -SkipStateWrite -SkipEventSync
                    if($null -ne $controlFlowState){
                        # BeforeAction may advance through one or more System nodes before it returns RUN.
                        # Treat every control-flow request as a potential mutation and checkpoint in bounded
                        # intervals; terminal boundaries are always flushed immediately.
                        $controlFlowMutationCount++
                        $controlFlowDirty=$true
                        $terminal=[string](Get-DynomaxPropertyValue -Object $controlFlowState -Name 'terminalStatus' -DefaultValue '')
                        Save-DynomaxHostControlFlowCheckpoint -Force:([bool]$terminal)
                    }
                }
                'RecordAttempt' {
                    $result=Invoke-DynomaxAttemptRecordOperation -RunDirectory $RunDirectory -RunId $RunId -StepOrder ([int]$args.stepOrder) -StepId ([string]$args.stepId) -ActionKey ([string]$args.actionKey) -ActionVersion ([int]$args.actionVersion) -ActionVersionId ([Guid]$args.actionVersionId) -AttemptNumber ([int]$args.attemptNumber) -StartedAtUtc ([string]$args.startedAtUtc) -EndedAtUtc ([string]$args.endedAtUtc) -Status ([string]$args.status) -MessageBase64 ([string](Get-DynomaxPropertyValue -Object $args -Name 'messageBase64' -DefaultValue '')) -RetryOnCsv ([string](Get-DynomaxPropertyValue -Object $args -Name 'retryOnCsv' -DefaultValue '')) -WaitBeforeExecutionSeconds ([int](Get-DynomaxPropertyValue -Object $args -Name 'waitBeforeExecutionSeconds' -DefaultValue 0)) -DelayBeforeNextAttemptSeconds ([int](Get-DynomaxPropertyValue -Object $args -Name 'delayBeforeNextAttemptSeconds' -DefaultValue 0)) -BrowserSessionDecision ([string](Get-DynomaxPropertyValue -Object $args -Name 'browserSessionDecision' -DefaultValue 'Reuse')) -EvidencePolicy ([string](Get-DynomaxPropertyValue -Object $args -Name 'evidencePolicy' -DefaultValue 'FinalFailureOnly')) -IsFinalAttempt (Get-DynomaxPropertyValue -Object $args -Name 'isFinalAttempt' -DefaultValue $false) -IsCleanup (Get-DynomaxPropertyValue -Object $args -Name 'isCleanup' -DefaultValue $false) -TimedOut (Get-DynomaxPropertyValue -Object $args -Name 'timedOut' -DefaultValue $false) -SensitiveAction (Get-DynomaxPropertyValue -Object $args -Name 'sensitiveAction' -DefaultValue $false) -DeclaredClassification ([string](Get-DynomaxPropertyValue -Object $args -Name 'declaredClassification' -DefaultValue ''))
                }
                'MarkActionRunning' {
                    $result=Invoke-DynomaxActionStartOperation -RunId $RunId -StepOrder ([int]$args.stepOrder) -StepId ([string]$args.stepId) -ActionKey ([string]$args.actionKey) -ActionVersionId ([Guid]$args.actionVersionId) -IsCleanup (Get-DynomaxPropertyValue -Object $args -Name 'isCleanup' -DefaultValue $false) -SqlConfig $sqlConfig -Connection $activeConnection
                }
                'PersistActionResult' {
                    $result=Invoke-DynomaxActionResultPersistenceOperation -RunId $RunId -StepOrder ([int]$args.stepOrder) -StepId ([string]$args.stepId) -ActionKey ([string]$args.actionKey) -ActionVersionId ([Guid]$args.actionVersionId) -RobotStatus ([string]$args.robotStatus) -MessageBase64 ([string](Get-DynomaxPropertyValue -Object $args -Name 'messageBase64' -DefaultValue '')) -IsCleanup (Get-DynomaxPropertyValue -Object $args -Name 'isCleanup' -DefaultValue $false) -ContextPath $ContextPath -SqlConfig $sqlConfig -Connection $activeConnection -PersistedContextCache $persistedContextCache
                }
                default { throw "Unsupported Dynomax orchestration operation '$operation'." }
            }
            Write-DynomaxHostResponse -Response ([ordered]@{id=$requestId;ok=$true;result=$result})
        }
        catch{
            try{Save-DynomaxHostControlFlowCheckpoint -Force}catch{}
            $message=[string]$_.Exception.Message
            if($message.Length -gt 4000){$message=$message.Substring(0,4000)}
            Write-DynomaxHostResponse -Response ([ordered]@{id=$requestId;ok=$false;errorCode='DYNOMAX_ORCHESTRATION_REQUEST_FAILED';message=$message})
        }
    }
}
finally{
    try{Save-DynomaxHostControlFlowCheckpoint -Force}catch{}
    if($null -ne $connection){$connection.Dispose()}
}
