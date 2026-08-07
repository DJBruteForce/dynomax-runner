[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
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
    [Parameter(Mandatory)][string]$Status,
    [string]$MessageBase64,
    [string]$RetryOnCsv,
    [int]$WaitBeforeExecutionSeconds = 0,
    [int]$DelayBeforeNextAttemptSeconds = 0,
    [string]$BrowserSessionDecision = 'Reuse',
    [string]$EvidencePolicy = 'FinalFailureOnly',
    [bool]$IsFinalAttempt = $false,
    [bool]$IsCleanup = $false,
    [bool]$TimedOut = $false,
    [bool]$SensitiveAction = $false,
    [string]$DeclaredClassification
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ExecutionPolicy.ps1')
$message = if ($MessageBase64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($MessageBase64)) } else { '' }
$classification = Get-DynomaxFailureClassification -Message $message -TimedOut:$TimedOut -DeclaredClassification $DeclaredClassification
$retryOn = @()
if ($RetryOnCsv) { $retryOn = @($RetryOnCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$retryable = $Status -ne 'PASS' -and $classification -and $retryOn -contains $classification -and -not $IsFinalAttempt
$effectiveFinalAttempt = $Status -ne 'PASS' -and -not $retryable
if (-not $retryable) { $DelayBeforeNextAttemptSeconds = 0 }
$evidenceRetained = $Status -ne 'PASS' -and ($EvidencePolicy -eq 'EveryFailedAttempt' -or $effectiveFinalAttempt)
$recordMessage = if ($SensitiveAction -and $Status -ne 'PASS') { 'Sensitive Action attempt failed; detailed message suppressed.' } else { $message }
$record = Write-DynomaxExecutionAttempt -RunDirectory $RunDirectory -RunId $RunId -StepOrder $StepOrder -StepId $StepId -ActionKey $ActionKey -ActionVersion $ActionVersion -ActionVersionId $ActionVersionId -AttemptNumber $AttemptNumber -StartedAtUtc ([datetime]::Parse($StartedAtUtc).ToUniversalTime()) -EndedAtUtc ([datetime]::Parse($EndedAtUtc).ToUniversalTime()) -Status $Status -Message $recordMessage -FailureClassification $classification -WaitBeforeExecutionSeconds $WaitBeforeExecutionSeconds -DelayBeforeNextAttemptSeconds $DelayBeforeNextAttemptSeconds -BrowserSessionDecision $BrowserSessionDecision -EvidencePolicy $EvidencePolicy -EvidenceRetained:$evidenceRetained -IsFinalAttempt:$effectiveFinalAttempt -IsCleanup:$IsCleanup
[ordered]@{ classification=$classification; retryable=[bool]$retryable; evidenceRetained=[bool]$evidenceRetained; record=$record } | ConvertTo-Json -Depth 20 -Compress
