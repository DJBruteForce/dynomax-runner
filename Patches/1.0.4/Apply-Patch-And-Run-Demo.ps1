[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$patchesDirectory = Split-Path -Parent $patchDirectory
$dynomaxRoot = Split-Path -Parent $patchesDirectory
$payloadRoot = Join-Path $patchDirectory 'Payload'

if (-not (Test-Path -LiteralPath (Join-Path $dynomaxRoot 'dynomax.json') -PathType Leaf)) {
    throw "Dynomax root was not found at '$dynomaxRoot'."
}
if (-not (Test-Path -LiteralPath $payloadRoot -PathType Container)) { throw 'Patch payload is missing.' }

$currentVersion = [System.IO.File]::ReadAllText((Join-Path $dynomaxRoot 'VERSION.txt')).Trim()
if ([version]$currentVersion -lt [version]'1.0.3') {
    throw "Dynomax 1.0.3 or later is required. Current version: $currentVersion"
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
$backupRoot = Join-Path $patchDirectory ("Backup\{0}" -f $timestamp)
[System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX 1.0.4: Apply generic framework refinements' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$payloadPrefix = $payloadRoot.TrimEnd('\') + '\'
foreach ($file in Get-ChildItem -LiteralPath $payloadRoot -File -Recurse) {
    $relativePath = $file.FullName.Substring($payloadPrefix.Length)
    $destinationPath = Join-Path $dynomaxRoot $relativePath
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destinationPath)) | Out-Null
    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $backupPath = Join-Path $backupRoot $relativePath
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backupPath)) | Out-Null
        Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
    }
    Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force
    Write-Host ("Updated {0}" -f $relativePath) -ForegroundColor Gray
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX 1.0.4: Register framework and demo project' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$configPath = Join-Path $dynomaxRoot 'dynomax.json'
& (Join-Path $dynomaxRoot 'Config-And-Setup\03-Core\Initialize-DynomaxCore.ps1') -DynomaxConfigPath $configPath
& (Join-Path $dynomaxRoot 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1') -DynomaxConfigPath $configPath
& (Join-Path $dynomaxRoot 'Project-Setup\Dynomax-Demo\Project-And-Config\Configure-Project.ps1')

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX DEMO: Execute composed project workflow' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$workflowScript = Join-Path $dynomaxRoot 'Project-Setup\Dynomax-Demo\Project-Workflow\Sessions\000001-ATX-Public-Homepage-Observation\Execute-Workflow.ps1'
$startedAt = [DateTime]::UtcNow
$powerShellExe = if ($PSVersionTable.PSEdition -eq 'Core') { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'powershell.exe' }
& $powerShellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $workflowScript
$workflowExitCode = $LASTEXITCODE

$exportPattern = 'Dynomax_dynomax-demo_demo.atx.public-homepage-observation_*.zip'
$resultZip = Get-ChildItem -LiteralPath (Join-Path $dynomaxRoot 'Exports') -Filter $exportPattern -File |
    Where-Object { $_.LastWriteTimeUtc -ge $startedAt.AddMinutes(-1) } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
if (-not $resultZip) { throw 'The demo workflow did not create a result ZIP.' }

try {
    $setClipboard = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
    if ($setClipboard -and $setClipboard.Parameters.ContainsKey('Path')) {
        Set-Clipboard -Path $resultZip.FullName
    }
    else {
        Add-Type -AssemblyName System.Windows.Forms
        $files = New-Object System.Collections.Specialized.StringCollection
        [void]$files.Add($resultZip.FullName)
        $data = New-Object System.Windows.Forms.DataObject
        $data.SetFileDropList($files)
        [System.Windows.Forms.Clipboard]::SetDataObject($data, $true)
    }
    Write-Host ("Result ZIP copied to clipboard: {0}" -f $resultZip.FullName) -ForegroundColor Green
}
catch {
    Write-Warning ("The result ZIP was created but clipboard copy failed: {0}" -f $_.Exception.Message)
}

Write-Host ''
Write-Host ("Demo result: {0}" -f $resultZip.FullName) -ForegroundColor Cyan
Write-Host 'The browser and child processes have been closed. This console will close automatically.' -ForegroundColor DarkGray
Start-Sleep -Seconds 2
exit $workflowExitCode
