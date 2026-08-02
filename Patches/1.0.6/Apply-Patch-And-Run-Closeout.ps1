[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$dynomaxRoot = Split-Path -Parent (Split-Path -Parent $patchDirectory)
$payloadRoot = Join-Path $patchDirectory 'Payload'
$logRoot = Join-Path $dynomaxRoot 'Logs\Patches\1.0.6'
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
$logPath = Join-Path $logRoot ('Dynomax-Patch-1.0.6-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '.log')
$transcriptStarted = $false
$exitCode = 1

try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true

    if (-not (Test-Path -LiteralPath (Join-Path $dynomaxRoot 'dynomax.json'))) {
        throw "Dynomax root was not found at '$dynomaxRoot'."
    }

    $versionPath = Join-Path $dynomaxRoot 'VERSION.txt'
    $currentVersion = if (Test-Path -LiteralPath $versionPath) {
        [System.IO.File]::ReadAllText($versionPath).Trim()
    } else {
        '0.0.0'
    }

    if ([version]$currentVersion -lt [version]'1.0.4') {
        throw "Dynomax 1.0.4 or later is required. Current version: $currentVersion"
    }

    $backupRoot = Join-Path $patchDirectory ('Backup\' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX 1.0.6: Apply closeout and failure diagnostics' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor DarkGray

    $prefix = $payloadRoot.TrimEnd('\') + '\'
    foreach ($file in Get-ChildItem -LiteralPath $payloadRoot -File -Recurse) {
        $relative = $file.FullName.Substring($prefix.Length)
        $destination = Join-Path $dynomaxRoot $relative
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null

        if (Test-Path -LiteralPath $destination) {
            $backup = Join-Path $backupRoot $relative
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backup)) | Out-Null
            Copy-Item -LiteralPath $destination -Destination $backup -Force
        }

        Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
        Write-Host ("Updated {0}" -f $relative) -ForegroundColor Gray
    }

    $configPath = Join-Path $dynomaxRoot 'dynomax.json'
    & (Join-Path $dynomaxRoot 'Config-And-Setup\03-Core\Initialize-DynomaxCore.ps1') -DynomaxConfigPath $configPath
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Core initialization exited with code $LASTEXITCODE." }

    & (Join-Path $dynomaxRoot 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1') -DynomaxConfigPath $configPath
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Installation validation exited with code $LASTEXITCODE." }

    & (Join-Path $dynomaxRoot 'Project-Setup\Dynomax-Demo\Project-And-Config\Configure-Project.ps1')
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "Demo project configuration exited with code $LASTEXITCODE." }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX 1.0.6: Execute complete evidence closeout demo' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan

    $workflowScript = Join-Path $dynomaxRoot 'Project-Setup\Dynomax-Demo\Project-Workflow\Sessions\000002-ATX-Public-Homepage-Complete-Evidence\Execute-Workflow.ps1'
    $started = [DateTime]::UtcNow
    $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'powershell.exe' }

    & $psExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $workflowScript
    $workflowExitCode = $LASTEXITCODE

    $pattern = 'Dynomax_dynomax-demo_demo.atx.public-homepage-complete-evidence_*.zip'
    $result = Get-ChildItem -LiteralPath (Join-Path $dynomaxRoot 'Exports') -Filter $pattern -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $started.AddMinutes(-1) } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($result) {
        Write-Host ("Closeout result ZIP: {0}" -f $result.FullName) -ForegroundColor Cyan
        Write-Host 'The ZIP was copied to the clipboard when Dynomax packaging succeeded.' -ForegroundColor Green
    } else {
        Write-Warning 'The closeout demo did not create a result ZIP.'
    }

    if ($workflowExitCode -ne 0) {
        throw "The closeout workflow failed with exit code $workflowExitCode. Review the output above and transcript '$logPath'."
    }

    if (-not $result) {
        throw "The closeout workflow returned success but no result ZIP was found. Review '$logPath'."
    }

    Write-Host ''
    Write-Host 'Dynomax 1.0.6 closeout completed successfully.' -ForegroundColor Green
    Write-Host 'The browser and child processes are closed. The console will close automatically.' -ForegroundColor DarkGray
    $exitCode = 0
}
catch {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host 'DYNOMAX 1.0.6 CLOSEOUT FAILED' -ForegroundColor Red
    Write-Host '============================================================' -ForegroundColor Red
    Write-Host ("Message: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    Write-Host ("Exception type: {0}" -f $_.Exception.GetType().FullName) -ForegroundColor Yellow
    if ($_.InvocationInfo) {
        Write-Host ("Script: {0}" -f $_.InvocationInfo.ScriptName) -ForegroundColor Yellow
        Write-Host ("Line: {0}" -f $_.InvocationInfo.ScriptLineNumber) -ForegroundColor Yellow
        Write-Host ("Position: {0}" -f $_.InvocationInfo.PositionMessage) -ForegroundColor DarkYellow
    }
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor Cyan
    Write-Host 'The BAT wrapper will keep this console open.' -ForegroundColor Cyan
    $exitCode = 1
}
finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}

exit $exitCode
