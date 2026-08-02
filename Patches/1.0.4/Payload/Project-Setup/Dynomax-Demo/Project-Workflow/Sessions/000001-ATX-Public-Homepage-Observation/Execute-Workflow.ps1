[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$current = $PSScriptRoot
while ($current -and -not (Test-Path (Join-Path $current 'dynomax.json'))) {
    $parent = Split-Path -Parent $current
    if ($parent -eq $current) { break }
    $current = $parent
}
if (-not $current -or -not (Test-Path (Join-Path $current 'dynomax.json'))) { throw 'Dynomax root not found.' }
& (Join-Path $current 'Core\Invoke-DynomaxWorkflow.ps1') -WorkflowDirectory $PSScriptRoot
exit $LASTEXITCODE
