[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [string]$ConfigPath,
    [switch]$AssertNoSqlFiles
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
function Assert-Contains([string]$RelativePath,[string]$Marker) {
    $path = Join-Path $SourceRoot ($RelativePath -replace '/', '\\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
    $content = [System.IO.File]::ReadAllText($path)
    if ($content.IndexOf($Marker,[System.StringComparison]::Ordinal) -lt 0) { throw "Marker '$Marker' was not found in '$RelativePath'." }
}
function Assert-NotContains([string]$RelativePath,[string]$Marker) {
    $path = Join-Path $SourceRoot ($RelativePath -replace '/', '\\')
    $content = [System.IO.File]::ReadAllText($path)
    if ($content.IndexOf($Marker,[System.StringComparison]::OrdinalIgnoreCase) -ge 0) { throw "Forbidden marker '$Marker' was found in '$RelativePath'." }
}
Assert-Contains 'Core/Execution/Dynomax.ExecutionPolicy.ps1' 'Get-DynomaxExecutionPolicy'
Assert-Contains 'Core/Execution/Dynomax.ExecutionPolicy.ps1' 'execution-attempts.jsonl'
Assert-Contains 'Core/Execution/Dynomax.ExecutionPolicy.ps1' 'ConfiguredTransientResult'
Assert-Contains 'Core/Execution/Dynomax.Workflow.ps1' 'Invoke-DynomaxPowerShellAction'
Assert-Contains 'Core/Execution/Dynomax.Workflow.ps1' 'Execute Dynomax Action With Policy'
Assert-Contains 'Core/Execution/Dynomax.Workflow.ps1' 'ConvertTo-DynomaxRobotCellValue'
Assert-Contains 'Core/Execution/Dynomax.Workflow.ps1' 'DYNOMAX_ACTION_METADATA_READY'
Assert-Contains 'Core/Robot/Dynomax.resource' 'result persistence was skipped so the runtime failure is classified as ERROR.'
Assert-Contains 'Core/Robot/Dynomax.resource' 'Run Dynomax Keyword With Timeout'
Assert-Contains 'Core/Robot/Dynomax.resource' '[Timeout]    ${timeout}'
Assert-Contains 'Core/Robot/Dynomax.resource' 'attempt-recorder${/}${DYNOMAX_STEP_ORDER}${/}${attempt}'
Assert-Contains 'Core/Robot/Dynomax.resource' 'Attempt evidence persistence also failed.'
Assert-NotContains 'Core/Robot/Dynomax.resource' 'Run Keyword With Timeout'
Assert-Contains 'Core/Execution/Record-DynomaxExecutionAttempt.ps1' 'ConvertTo-DynomaxStrictBoolean'
Assert-Contains 'Core/Execution/Record-DynomaxExecutionAttempt.ps1' 'Join-Path $PSScriptRoot'
Assert-Contains 'Core/Execution/Record-DynomaxExecutionAttempt.ps1' 'Dynomax.ExecutionPolicy.ps1'
$workflowScript = Join-Path $SourceRoot 'Core\Execution\Dynomax.Workflow.ps1'
. $workflowScript
$emptyRobotCell = ConvertTo-DynomaxRobotCellValue -Value ''
if ($emptyRobotCell -ne '${EMPTY}') { throw "Empty Robot cell value must be emitted as `${EMPTY}; actual '$emptyRobotCell'." }
$nullRobotCell = ConvertTo-DynomaxRobotCellValue -Value $null
if ($nullRobotCell -ne '${EMPTY}') { throw "Null Robot cell value must be emitted as `${EMPTY}; actual '$nullRobotCell'." }
$retryRobotCell = ConvertTo-DynomaxRobotCellValue -Value 'Http429,NavigationTimeout'
if ($retryRobotCell -ne 'Http429,NavigationTimeout') { throw "Non-empty Robot cell value changed unexpectedly: '$retryRobotCell'." }
Assert-Contains 'Core/Robot/Dynomax.resource' 'EveryFailedAttempt'
Assert-Contains 'Core/Results/Dynomax.Results.ps1' 'actionsRecoveredAfterRetry'
foreach ($file in @('Core/Execution/Dynomax.ExecutionPolicy.ps1','Core/Execution/Record-DynomaxExecutionAttempt.ps1')) {
    Assert-NotContains $file 'dynomax.website.open'
    Assert-NotContains $file 'dynomax.auth.login'
    Assert-NotContains $file 'self-test'
}
$version = [System.IO.File]::ReadAllText((Join-Path $SourceRoot 'VERSION.txt')).Trim()
if ($version -ne '1.0.11') { throw "VERSION.txt must contain 1.0.11 but contains '$version'." }
if ($ConfigPath) {
    $config = [System.IO.File]::ReadAllText($ConfigPath) | ConvertFrom-Json
    if ([string]$config.frameworkVersion -ne '1.0.11') { throw 'dynomax.json frameworkVersion must be 1.0.11.' }
}
if ($AssertNoSqlFiles -and @(Get-ChildItem -LiteralPath $SourceRoot -Filter '*.sql' -File -Recurse).Count -gt 0) { throw 'The Core package must not contain SQL files.' }
Write-Host 'PASS  Core 1.0.11 execution-policy contract checks.' -ForegroundColor Green
