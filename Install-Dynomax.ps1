[CmdletBinding()]
param(
    [switch]$SkipPrerequisiteInstallation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$configPath = Join-Path $root 'dynomax.json'

$steps = @(
    @{ Name = 'Prerequisites'; Script = 'Config-And-Setup\01-Prerequisites\Invoke-PrerequisiteSetup.ps1'; Parameters = @{} },
    @{ Name = 'Database'; Script = 'Config-And-Setup\02-Database\Initialize-DynomaxDatabase.ps1'; Parameters = @{} },
    @{ Name = 'Core'; Script = 'Config-And-Setup\03-Core\Initialize-DynomaxCore.ps1'; Parameters = @{} },
    @{ Name = 'Validation'; Script = 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1'; Parameters = @{ SkipWebsiteValidation = $true } }
)

if ($SkipPrerequisiteInstallation) {
    $steps[0]['Parameters']['CheckOnly'] = $true
}

foreach ($step in $steps) {
    $scriptPath = Join-Path $root $step.Script
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host ("DYNOMAX SETUP: {0}" -f $step.Name) -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    $parameters = @{} + $step.Parameters
    $parameters.DynomaxConfigPath = $configPath
    & $scriptPath @parameters
}
