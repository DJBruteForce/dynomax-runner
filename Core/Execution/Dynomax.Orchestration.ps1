Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-DynomaxOrchestrationBoolean {
    [CmdletBinding()]
    param([AllowNull()][object]$Value,[Parameter(Mandatory)][string]$ParameterName)
    if ($Value -is [bool]) { return [bool]$Value }
    if ($null -eq $Value) { return $false }
    $text = ([string]$Value).Trim()
    switch ($text.ToLowerInvariant()) {
        'true'  { return $true }
        'false' { return $false }
        '1'     { return $true }
        '0'     { return $false }
        default { throw "Parameter '$ParameterName' must be True, False, 1 or 0; actual '$text'." }
    }
}

function Invoke-DynomaxControlFlowOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('BeforeAction','AfterAction','ReuseAction','FailAction','AssertDiscoveryTarget')][string]$Mode,
        [Parameter(Mandatory)]$Workflow,
        [Parameter(Mandatory)][string]$ContextPath,
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$NodeId,
        [Parameter(Mandatory)]$SqlConfig,
        [System.Data.SqlClient.SqlConnection]$Connection,
        $State=$null,
        [switch]$SkipStateWrite,
        [switch]$SkipEventSync
    )

    if($Mode -eq 'BeforeAction'){
        $decision=Get-DynomaxControlFlowDecision -Workflow $Workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $NodeId -State $State
        return ([string]$decision.Disposition).ToUpperInvariant()
    }
    if($Mode -eq 'FailAction'){
        $state=Fail-DynomaxControlFlowAction -Workflow $Workflow -RunDirectory $RunDirectory -NodeId $NodeId -DeferStateWrite -State $State
        if(-not $SkipEventSync){
            [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $SqlConfig -RunId $RunId -RunDirectory $RunDirectory -Connection $Connection -State $state -SkipStateWrite:$SkipStateWrite)
        }
        return 'OK'
    }
    if($Mode -eq 'AssertDiscoveryTarget'){
        [void](Assert-DynomaxDiscoveryTargetReached -Workflow $Workflow -RunDirectory $RunDirectory -State $State)
        return 'OK'
    }

    $reused=$Mode -eq 'ReuseAction'
    $state=Complete-DynomaxControlFlowAction -Workflow $Workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $NodeId -Reused:$reused -DeferStateWrite -State $State
    if($reused){
        Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Continuation.Reused' -Message "Physical Action visit '$NodeId' was reused from the immutable continuation plan; it was not executed in this Run." -Data ([ordered]@{workflowNodeId=$NodeId;executionKind='Reused';executed=$false}) -Connection $Connection
    }
    if(-not $SkipEventSync){
        [void](Sync-DynomaxControlFlowRunEvents -SqlConfig $SqlConfig -RunId $RunId -RunDirectory $RunDirectory -Connection $Connection -State $state -SkipStateWrite:$SkipStateWrite)
    }
    $waitingForUser=[bool](Get-DynomaxPropertyValue -Object $state -Name 'waitingForUser' -DefaultValue $false)
    if($waitingForUser){return 'WAITING_FOR_USER'}
    $terminalStatus=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
    if($terminalStatus){return ('TERMINAL_{0}' -f $terminalStatus.ToUpperInvariant())}
    return 'CONTINUE'
}

function Invoke-DynomaxAttemptRecordOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$StepId,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][int]$ActionVersion,
        [Parameter(Mandatory)][Guid]$ActionVersionId,
        [Parameter(Mandatory)][int]$AttemptNumber,
        [Parameter(Mandatory)][string]$StartedAtUtc,
        [Parameter(Mandatory)][string]$EndedAtUtc,
        [Parameter(Mandatory)][ValidateSet('PASS','FAIL')][string]$Status,
        [string]$MessageBase64,
        [string]$RetryOnCsv,
        [int]$WaitBeforeExecutionSeconds = 0,
        [int]$DelayBeforeNextAttemptSeconds = 0,
        [string]$BrowserSessionDecision = 'Reuse',
        [string]$EvidencePolicy = 'FinalFailureOnly',
        [object]$IsFinalAttempt = $false,
        [object]$IsCleanup = $false,
        [object]$TimedOut = $false,
        [object]$SensitiveAction = $false,
        [string]$DeclaredClassification
    )

    $isFinalAttemptValue = ConvertTo-DynomaxOrchestrationBoolean -Value $IsFinalAttempt -ParameterName 'IsFinalAttempt'
    $isCleanupValue = ConvertTo-DynomaxOrchestrationBoolean -Value $IsCleanup -ParameterName 'IsCleanup'
    $timedOutValue = ConvertTo-DynomaxOrchestrationBoolean -Value $TimedOut -ParameterName 'TimedOut'
    $sensitiveActionValue = ConvertTo-DynomaxOrchestrationBoolean -Value $SensitiveAction -ParameterName 'SensitiveAction'
    $message = if ($MessageBase64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($MessageBase64)) } else { '' }
    $classification = Get-DynomaxFailureClassification -Message $message -TimedOut:$timedOutValue -DeclaredClassification $DeclaredClassification
    $retryOn = @()
    if ($RetryOnCsv) { $retryOn = @($RetryOnCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
    $retryable = $Status -ne 'PASS' -and $classification -and $retryOn -contains $classification -and -not $isFinalAttemptValue
    $effectiveFinalAttempt = $Status -ne 'PASS' -and -not $retryable
    if (-not $retryable) { $DelayBeforeNextAttemptSeconds = 0 }
    $evidenceRetained = $Status -ne 'PASS' -and ($EvidencePolicy -eq 'EveryFailedAttempt' -or $effectiveFinalAttempt)
    $recordMessage = if ($sensitiveActionValue -and $Status -ne 'PASS') { 'Sensitive Action attempt failed; detailed message suppressed.' } else { $message }
    $record = Write-DynomaxExecutionAttempt -RunDirectory $RunDirectory -RunId $RunId -StepOrder $StepOrder -StepId $StepId -ActionKey $ActionKey -ActionVersion $ActionVersion -ActionVersionId $ActionVersionId -AttemptNumber $AttemptNumber -StartedAtUtc ([datetime]::Parse($StartedAtUtc).ToUniversalTime()) -EndedAtUtc ([datetime]::Parse($EndedAtUtc).ToUniversalTime()) -Status $Status -Message $recordMessage -FailureClassification $classification -WaitBeforeExecutionSeconds $WaitBeforeExecutionSeconds -DelayBeforeNextAttemptSeconds $DelayBeforeNextAttemptSeconds -BrowserSessionDecision $BrowserSessionDecision -EvidencePolicy $EvidencePolicy -EvidenceRetained:$evidenceRetained -TimedOut:$timedOutValue -IsFinalAttempt:$effectiveFinalAttempt -IsCleanup:$isCleanupValue
    return [ordered]@{ classification=$classification; retryable=[bool]$retryable; evidenceRetained=[bool]$evidenceRetained; timedOut=[bool]$timedOutValue; record=$record }
}

function Invoke-DynomaxActionStartOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$StepId,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][Guid]$ActionVersionId,
        [Parameter(Mandatory)][object]$IsCleanup,
        [Parameter(Mandatory)]$SqlConfig,
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    $cleanup=ConvertTo-DynomaxOrchestrationBoolean -Value $IsCleanup -ParameterName 'IsCleanup'
    $stream=if($cleanup){'CleanupActionStarted'}else{'MainActionStarted'}
    $eventId=Get-DynomaxControlFlowRunEventId -RunId $RunId -Stream $stream -Sequence $StepOrder
    Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Runtime.ActionStarted' -Message "Action '$ActionKey' started." -Data ([ordered]@{stepOrder=$StepOrder;stepId=$StepId;actionKey=$ActionKey;actionVersionId=$ActionVersionId.ToString('D');isCleanup=$cleanup}) -RunEventId $eventId -Connection $Connection
    return [ordered]@{status='RUNNING';stepOrder=$StepOrder;stepId=$StepId;actionKey=$ActionKey}
}

function Invoke-DynomaxActionResultPersistenceOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$StepId,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][Guid]$ActionVersionId,
        [Parameter(Mandatory)][string]$RobotStatus,
        [string]$MessageBase64,
        [Parameter(Mandatory)][object]$IsCleanup,
        [Parameter(Mandatory)][string]$ContextPath,
        [Parameter(Mandatory)]$SqlConfig,
        [System.Data.SqlClient.SqlConnection]$Connection,
        [hashtable]$PersistedContextCache
    )

    $message=''
    if($MessageBase64){$message=[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($MessageBase64))}
    $context=Read-DynomaxJson -Path $ContextPath
    $classificationProperty="currentClassification.$ActionKey"
    $explicit=$null
    if($context.values.PSObject.Properties.Name -contains $classificationProperty){$explicit=[string]$context.values.$classificationProperty}
    $status=switch($RobotStatus.ToUpperInvariant()){'PASS'{'PASS'} 'SKIP'{'SKIPPED'} default {if($explicit){$explicit}else{'FAIL'}}}
    $cleanup=ConvertTo-DynomaxOrchestrationBoolean -Value $IsCleanup -ParameterName 'IsCleanup'
    if($cleanup -and $status -notin @('PASS','SKIPPED')){$status='CLEANUP_FAILED'}

    $output=[ordered]@{}
    $pool=Get-DynomaxPropertyValue -Object $context -Name 'runDataPool' -DefaultValue $null
    $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
    $stepProperty=if($null -ne $steps){$steps.PSObject.Properties[$StepId]}else{$null}
    if($null -ne $stepProperty){
        $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
        if($null -ne $outputs){foreach($property in @($outputs.PSObject.Properties)){
            $entry=$property.Value
            $available=[bool](Get-DynomaxPropertyValue -Object $entry -Name 'available' -DefaultValue $false)
            $classification=[string](Get-DynomaxPropertyValue -Object $entry -Name 'classification' -DefaultValue 'Normal')
            $persist=[bool](Get-DynomaxPropertyValue -Object $entry -Name 'persistInResult' -DefaultValue $true)
            if($available -and $classification -eq 'Normal' -and $persist){$output[[string]$property.Name]=Get-DynomaxPropertyValue -Object $entry -Name 'value' -DefaultValue $null}
        }}
    }
    $outputJson=$output|ConvertTo-Json -Depth 50 -Compress
    Add-DynomaxActionRun -SqlConfig $SqlConfig -RunId $RunId -StepOrder $StepOrder -ActionKey $ActionKey -ActionVersionId $ActionVersionId -Status $status -Message $message -OutputJson $outputJson -IsCleanup:$cleanup -Connection $Connection
    if($status -notin @('PASS','SKIPPED') -and -not $cleanup){
        if(-not ($context.values.PSObject.Properties.Name -contains 'workflowBlocked')){Add-Member -InputObject $context.values -NotePropertyName 'workflowBlocked' -NotePropertyValue $true}else{$context.values.workflowBlocked=$true}
        Write-DynomaxJson -Value $context -Path $ContextPath
    }
    Set-DynomaxContextStepInSql -SqlConfig $SqlConfig -RunId $RunId -Context $context -StepId $StepId -Connection $Connection -PersistedContextCache $PersistedContextCache
    return [ordered]@{status=$status;stepOrder=$StepOrder;stepId=$StepId;actionKey=$ActionKey}
}
