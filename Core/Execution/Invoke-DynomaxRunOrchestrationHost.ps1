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

function Get-DynomaxHostConnection {
    if($null -eq $script:connection -or $script:connection.State -in @([System.Data.ConnectionState]::Closed,[System.Data.ConnectionState]::Broken)){
        if($null -ne $script:connection){try{$script:connection.Dispose()}catch{};$script:connection=$null}
        $script:connection=Open-DynomaxConnection -SqlConfig $script:sqlConfig
    }
    return $script:connection
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
                Write-DynomaxHostResponse -Response ([ordered]@{id=$requestId;ok=$true;result='OK'})
                break
            }
            $activeConnection=Get-DynomaxHostConnection
            switch($operation){
                'Ping' { $result='OK' }
                'ControlFlow' {
                    $result=Invoke-DynomaxControlFlowOperation -Mode ([string]$args.mode) -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -RunId $RunId -NodeId ([string]$args.nodeId) -SqlConfig $sqlConfig -Connection $activeConnection
                }
                'RecordAttempt' {
                    $result=Invoke-DynomaxAttemptRecordOperation -RunDirectory $RunDirectory -RunId $RunId -StepOrder ([int]$args.stepOrder) -StepId ([string]$args.stepId) -ActionKey ([string]$args.actionKey) -ActionVersion ([int]$args.actionVersion) -ActionVersionId ([Guid]$args.actionVersionId) -AttemptNumber ([int]$args.attemptNumber) -StartedAtUtc ([string]$args.startedAtUtc) -EndedAtUtc ([string]$args.endedAtUtc) -Status ([string]$args.status) -MessageBase64 ([string](Get-DynomaxPropertyValue -Object $args -Name 'messageBase64' -DefaultValue '')) -RetryOnCsv ([string](Get-DynomaxPropertyValue -Object $args -Name 'retryOnCsv' -DefaultValue '')) -WaitBeforeExecutionSeconds ([int](Get-DynomaxPropertyValue -Object $args -Name 'waitBeforeExecutionSeconds' -DefaultValue 0)) -DelayBeforeNextAttemptSeconds ([int](Get-DynomaxPropertyValue -Object $args -Name 'delayBeforeNextAttemptSeconds' -DefaultValue 0)) -BrowserSessionDecision ([string](Get-DynomaxPropertyValue -Object $args -Name 'browserSessionDecision' -DefaultValue 'Reuse')) -EvidencePolicy ([string](Get-DynomaxPropertyValue -Object $args -Name 'evidencePolicy' -DefaultValue 'FinalFailureOnly')) -IsFinalAttempt (Get-DynomaxPropertyValue -Object $args -Name 'isFinalAttempt' -DefaultValue $false) -IsCleanup (Get-DynomaxPropertyValue -Object $args -Name 'isCleanup' -DefaultValue $false) -TimedOut (Get-DynomaxPropertyValue -Object $args -Name 'timedOut' -DefaultValue $false) -SensitiveAction (Get-DynomaxPropertyValue -Object $args -Name 'sensitiveAction' -DefaultValue $false) -DeclaredClassification ([string](Get-DynomaxPropertyValue -Object $args -Name 'declaredClassification' -DefaultValue ''))
                }
                'PersistActionResult' {
                    $result=Invoke-DynomaxActionResultPersistenceOperation -RunId $RunId -StepOrder ([int]$args.stepOrder) -StepId ([string]$args.stepId) -ActionKey ([string]$args.actionKey) -ActionVersionId ([Guid]$args.actionVersionId) -RobotStatus ([string]$args.robotStatus) -MessageBase64 ([string](Get-DynomaxPropertyValue -Object $args -Name 'messageBase64' -DefaultValue '')) -IsCleanup (Get-DynomaxPropertyValue -Object $args -Name 'isCleanup' -DefaultValue $false) -ContextPath $ContextPath -SqlConfig $sqlConfig -Connection $activeConnection -PersistedContextCache $persistedContextCache
                }
                default { throw "Unsupported Dynomax orchestration operation '$operation'." }
            }
            Write-DynomaxHostResponse -Response ([ordered]@{id=$requestId;ok=$true;result=$result})
        }
        catch{
            $message=[string]$_.Exception.Message
            if($message.Length -gt 4000){$message=$message.Substring(0,4000)}
            Write-DynomaxHostResponse -Response ([ordered]@{id=$requestId;ok=$false;errorCode='DYNOMAX_ORCHESTRATION_REQUEST_FAILED';message=$message})
        }
    }
}
finally{
    if($null -ne $connection){$connection.Dispose()}
}
