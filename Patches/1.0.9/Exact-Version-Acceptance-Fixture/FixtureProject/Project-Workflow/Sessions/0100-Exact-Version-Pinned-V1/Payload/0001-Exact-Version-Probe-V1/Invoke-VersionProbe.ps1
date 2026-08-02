[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DynomaxRoot,
    [Parameter(Mandatory = $true)][Guid]$RunId,
    [Parameter(Mandatory = $true)][int]$StepOrder,
    [Parameter(Mandatory = $true)][string]$ContextPath,
    [Parameter(Mandatory = $true)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')

$result = [ordered]@{
    status = 'PASS'
    message = 'Exact-version probe executed VERSION-1.'
    marker = 'VERSION-1'
    probeVersion = 1
    runId = [string]$RunId
    stepOrder = $StepOrder
    contextPath = $ContextPath
}
Write-DynomaxJson -Value $result -Path $OutputPath
