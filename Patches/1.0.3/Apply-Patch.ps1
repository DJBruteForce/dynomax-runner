[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$patchesDirectory = Split-Path -Parent $patchDirectory
$dynomaxRoot = Split-Path -Parent $patchesDirectory
$payloadRoot = Join-Path $patchDirectory 'Payload'

if (-not (Test-Path -LiteralPath (Join-Path $dynomaxRoot 'dynomax.json') -PathType Leaf)) {
    throw "Dynomax root was not found at '$dynomaxRoot'. Extract the patch ZIP to C:\."
}
if (-not (Test-Path -LiteralPath $payloadRoot -PathType Container)) {
    throw 'Patch payload is missing.'
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
$backupRoot = Join-Path $patchDirectory ("Backup\{0}" -f $timestamp)
$legacyRoot = Join-Path $patchesDirectory 'Legacy\1.0.2'
[System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($legacyRoot) | Out-Null

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX PATCH 1.0.3: Clean legacy patch files' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
foreach ($legacyName in @('Apply-Dynomax-Patch-1.0.2.bat','Apply-Dynomax-Patch-1.0.2.ps1','PATCH_1_0_1.md','PATCH_1_0_2.md')) {
    $legacyPath = Join-Path $dynomaxRoot $legacyName
    if (Test-Path -LiteralPath $legacyPath -PathType Leaf) {
        $destination = Join-Path $legacyRoot $legacyName
        Move-Item -LiteralPath $legacyPath -Destination $destination -Force
        Write-Host ("Moved {0} to Patches\Legacy\1.0.2." -f $legacyName) -ForegroundColor DarkGray
    }
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX PATCH 1.0.3: Apply payload' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$payloadPrefix = $payloadRoot.TrimEnd('\') + '\'
foreach ($file in Get-ChildItem -LiteralPath $payloadRoot -File -Recurse) {
    $relativePath = $file.FullName.Substring($payloadPrefix.Length)
    $destinationPath = Join-Path $dynomaxRoot $relativePath
    $destinationDirectory = Split-Path -Parent $destinationPath
    [System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $backupPath = Join-Path $backupRoot $relativePath
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backupPath)) | Out-Null
        Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
    }

    Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
    Write-Host ("Updated {0}" -f $relativePath) -ForegroundColor Gray
}

$configPath = Join-Path $dynomaxRoot 'dynomax.json'

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX PATCH 1.0.3: Database migration' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
& (Join-Path $dynomaxRoot 'Config-And-Setup\02-Database\Initialize-DynomaxDatabase.ps1') -DynomaxConfigPath $configPath

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX PATCH 1.0.3: Core version registration' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
& (Join-Path $dynomaxRoot 'Config-And-Setup\03-Core\Initialize-DynomaxCore.ps1') -DynomaxConfigPath $configPath

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX PATCH 1.0.3: Installation validation' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
& (Join-Path $dynomaxRoot 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1') -DynomaxConfigPath $configPath

Write-Host ''
Write-Host 'Dynomax 1.0.3 patch applied successfully.' -ForegroundColor Green
Write-Host 'Next: run C:\Dynomax\Run-Dynomax-Self-Test.bat' -ForegroundColor Cyan
