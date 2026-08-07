[CmdletBinding()]
param([string]$BackupPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$dynomaxRoot = Split-Path -Parent (Split-Path -Parent $patchDirectory)
$backupBase = Join-Path $dynomaxRoot 'Backups\Core-1.0.11'
if (-not $BackupPath) {
    $latest = Get-ChildItem -LiteralPath $backupBase -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $latest) { throw "No Core 1.0.11 rollback backup exists under '$backupBase'." }
    $BackupPath = $latest.FullName
}
$BackupPath = [System.IO.Path]::GetFullPath($BackupPath)
$manifestPath = Join-Path $BackupPath 'backup-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Backup manifest was not found at '$manifestPath'." }
$manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
if ([string]$manifest.dynomaxRoot -and
    -not [string]::Equals([System.IO.Path]::GetFullPath([string]$manifest.dynomaxRoot),$dynomaxRoot,[System.StringComparison]::OrdinalIgnoreCase)) {
    throw "The selected backup belongs to a different Dynomax root."
}
foreach ($entry in @($manifest.files)) {
    $relative = [string]$entry.path
    if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)' -or $relative -match '^[A-Za-z]:') { throw "Unsafe backup path '$relative'." }
    $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
    if ([bool]$entry.existed) {
        $source = Join-Path $BackupPath ($relative -replace '/', '\\')
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Backup file is missing: $source" }
        [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
    elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
        Remove-Item -LiteralPath $destination -Force
    }
}
Write-Host "Dynomax Core rollback completed from: $BackupPath" -ForegroundColor Green
