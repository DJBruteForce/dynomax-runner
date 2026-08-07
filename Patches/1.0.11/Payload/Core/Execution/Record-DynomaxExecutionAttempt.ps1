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
    [object]$IsFinalAttempt = $false,
    [object]$IsCleanup = $false,
    [object]$TimedOut = $false,
    [object]$SensitiveAction = $false,
    [string]$DeclaredClassification
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $PSScriptRoot 'Dynomax.ExecutionPolicy.ps1')

function ConvertTo-DynomaxStrictBoolean {
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

$isFinalAttemptValue = ConvertTo-DynomaxStrictBoolean -Value $IsFinalAttempt -ParameterName 'IsFinalAttempt'
$isCleanupValue = ConvertTo-DynomaxStrictBoolean -Value $IsCleanup -ParameterName 'IsCleanup'
$timedOutValue = ConvertTo-DynomaxStrictBoolean -Value $TimedOut -ParameterName 'TimedOut'
$sensitiveActionValue = ConvertTo-DynomaxStrictBoolean -Value $SensitiveAction -ParameterName 'SensitiveAction'
$message = if ($MessageBase64) { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($MessageBase64)) } else { '' }
$classification = Get-DynomaxFailureClassification -Message $message -TimedOut:$timedOutValue -DeclaredClassification $DeclaredClassification
$retryOn = @()
if ($RetryOnCsv) { $retryOn = @($RetryOnCsv.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$retryable = $Status -ne 'PASS' -and $classification -and $retryOn -contains $classification -and -not $isFinalAttemptValue
$effectiveFinalAttempt = $Status -ne 'PASS' -and -not $retryable
if (-not $retryable) { $DelayBeforeNextAttemptSeconds = 0 }
$evidenceRetained = $Status -ne 'PASS' -and ($EvidencePolicy -eq 'EveryFailedAttempt' -or $effectiveFinalAttempt)
$recordMessage = if ($sensitiveActionValue -and $Status -ne 'PASS') { 'Sensitive Action attempt failed; detailed message suppressed.' } else { $message }
$record = Write-DynomaxExecutionAttempt -RunDirectory $RunDirectory -RunId $RunId -StepOrder $StepOrder -StepId $StepId -ActionKey $ActionKey -ActionVersion $ActionVersion -ActionVersionId $ActionVersionId -AttemptNumber $AttemptNumber -StartedAtUtc ([datetime]::Parse($StartedAtUtc).ToUniversalTime()) -EndedAtUtc ([datetime]::Parse($EndedAtUtc).ToUniversalTime()) -Status $Status -Message $recordMessage -FailureClassification $classification -WaitBeforeExecutionSeconds $WaitBeforeExecutionSeconds -DelayBeforeNextAttemptSeconds $DelayBeforeNextAttemptSeconds -BrowserSessionDecision $BrowserSessionDecision -EvidencePolicy $EvidencePolicy -EvidenceRetained:$evidenceRetained -IsFinalAttempt:$effectiveFinalAttempt -IsCleanup:$isCleanupValue
[ordered]@{ classification=$classification; retryable=[bool]$retryable; evidenceRetained=[bool]$evidenceRetained; record=$record } | ConvertTo-Json -Depth 20 -Compress
