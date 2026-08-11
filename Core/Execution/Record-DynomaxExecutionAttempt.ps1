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
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $PSScriptRoot 'Dynomax.ExecutionPolicy.ps1')
. (Join-Path $PSScriptRoot 'Dynomax.Orchestration.ps1')
$result=Invoke-DynomaxAttemptRecordOperation -RunDirectory $RunDirectory -RunId $RunId -StepOrder $StepOrder -StepId $StepId -ActionKey $ActionKey -ActionVersion $ActionVersion -ActionVersionId $ActionVersionId -AttemptNumber $AttemptNumber -StartedAtUtc $StartedAtUtc -EndedAtUtc $EndedAtUtc -Status $Status -MessageBase64 $MessageBase64 -RetryOnCsv $RetryOnCsv -WaitBeforeExecutionSeconds $WaitBeforeExecutionSeconds -DelayBeforeNextAttemptSeconds $DelayBeforeNextAttemptSeconds -BrowserSessionDecision $BrowserSessionDecision -EvidencePolicy $EvidencePolicy -IsFinalAttempt $IsFinalAttempt -IsCleanup $IsCleanup -TimedOut $TimedOut -SensitiveAction $SensitiveAction -DeclaredClassification $DeclaredClassification
$result | ConvertTo-Json -Depth 20 -Compress
