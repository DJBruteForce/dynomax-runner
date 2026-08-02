[CmdletBinding()]
param([string]$BackupDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$dynomaxRoot = Split-Path -Parent (Split-Path -Parent $patchDirectory)
$validatorPath = Join-Path $patchDirectory 'Validate-ExecutableScripts.ps1'
$logRoot = Join-Path $dynomaxRoot 'Logs\Patches\1.0.9'
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
$logPath = Join-Path $logRoot ('Dynomax-Rollback-1.0.9-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '.log')
$transcriptStarted = $false
$exitCode = 1
try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true
    if (-not $BackupDirectory) {
        $latest = Get-ChildItem -LiteralPath (Join-Path $patchDirectory 'Backup') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if (-not $latest) { throw 'No Dynomax 1.0.9 backup directory was found.' }
        $BackupDirectory = $latest.FullName
    }
    $backupRoot = [System.IO.Path]::GetFullPath($BackupDirectory)
    $manifestPath = Join-Path $backupRoot 'backup-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Backup manifest was not found: '$manifestPath'." }
    $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    if ([string]$manifest.patchVersion -ne '1.0.9') { throw 'The selected backup is not a Dynomax 1.0.9 backup.' }
    foreach ($entry in @($manifest.files)) {
        $relative = [string]$entry.path
        if ([System.IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') { throw "Unsafe backup path '$relative'." }
        $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
        if ([bool]$entry.existed) {
            $source = Join-Path $backupRoot ($relative -replace '/', '\\')
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Backup file is missing: '$source'." }
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Force
            Write-Host ("Restored {0}" -f $relative) -ForegroundColor Gray
        } elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force
            Write-Host ("Removed {0}" -f $relative) -ForegroundColor Gray
        }
    }
    $windowsPowerShell = (Get-Command 'powershell.exe' -ErrorAction Stop).Source
    & $windowsPowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $validatorPath -RootPath (Join-Path $dynomaxRoot 'Core')
    if ([int]$LASTEXITCODE -ne 0) { throw "Post-rollback Core parser gate failed with code $LASTEXITCODE." }
    Write-Host 'Dynomax 1.0.9 rollback completed. No SQL rollback was required.' -ForegroundColor Green
    $exitCode = 0
} catch {
    Write-Host 'DYNOMAX 1.0.9 ROLLBACK FAILED' -ForegroundColor Red
    Write-Host ("Message: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor Cyan
    $exitCode = 1
} finally {
    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
}
exit $exitCode
