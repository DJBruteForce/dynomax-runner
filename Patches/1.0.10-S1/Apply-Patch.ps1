[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$dynomaxRoot = Split-Path -Parent (Split-Path -Parent $patchDirectory)
$payloadRoot = Join-Path $patchDirectory 'Payload'
$manifestPath = Join-Path $patchDirectory 'PATCH_MANIFEST.json'
$validatorPath = Join-Path $patchDirectory 'Validate-ExecutableScripts.ps1'
$contractPath = Join-Path $patchDirectory 'Test-ExactVersionPatch.ps1'
$logRoot = Join-Path $dynomaxRoot 'Logs\Patches\1.0.10-S1'
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
$logPath = Join-Path $logRoot ('Dynomax-Patch-1.0.10-S1-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '.log')
$transcriptStarted = $false
$exitCode = 1
$activeBackupRoot = $null

function Get-DynomaxFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-DynomaxNativeStep {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )
    Write-Host ("[Dynomax] START {0}" -f $Name) -ForegroundColor Cyan
    & $Executable @Arguments
    $code = [int]$LASTEXITCODE
    Write-Host ("[Dynomax] END {0}; exit {1}" -f $Name, $code) -ForegroundColor DarkGray
    if ($code -ne 0) { throw "$Name exited with code $code." }
}

function Assert-DynomaxManifestFiles {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)]$Manifest
    )
    foreach ($entry in @($Manifest.files)) {
        $relative = [string]$entry.path
        if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Unsafe manifest path '$relative'."
        }
        $path = Join-Path $Root ($relative -replace '/', '\\')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Manifest file is missing: $path" }
        $actual = Get-DynomaxFileSha256 -Path $path
        if ($actual -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "SHA-256 mismatch for '$relative'. Expected $($entry.sha256), found $actual." }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.length) { throw "Length mismatch for '$relative'." }
    }
}

function Restore-DynomaxBackup {
    param([Parameter(Mandatory = $true)][string]$BackupRoot)
    $backupManifestPath = Join-Path $BackupRoot 'backup-manifest.json'
    if (-not (Test-Path -LiteralPath $backupManifestPath -PathType Leaf)) { return }
    $backupManifest = [System.IO.File]::ReadAllText($backupManifestPath) | ConvertFrom-Json
    foreach ($entry in @($backupManifest.files)) {
        $relative = [string]$entry.path
        $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
        if ([bool]$entry.existed) {
            $source = Join-Path $BackupRoot ($relative -replace '/', '\\')
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
                Copy-Item -LiteralPath $source -Destination $destination -Force
            }
        } elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force
        }
    }
}

try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true
    if (-not (Test-Path -LiteralPath (Join-Path $dynomaxRoot 'dynomax.json') -PathType Leaf)) { throw "Dynomax root was not found at '$dynomaxRoot'." }
    foreach ($required in @($payloadRoot,$manifestPath,$validatorPath,$contractPath)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Patch component is missing: $required" }
    }

    $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    if ([string]$manifest.patchVersion -ne '1.0.10-S1') { throw 'Patch manifest version is not 1.0.10-S1.' }
    $currentVersionText = [System.IO.File]::ReadAllText((Join-Path $dynomaxRoot 'VERSION.txt')).Trim()
    $currentVersion = [version]$currentVersionText
    if ($currentVersion -ne [version]'1.0.10') {
        throw "Dynomax Core 1.0.10 is required. Current version: $currentVersionText"
    }

    $windowsPowerShell = (Get-Command 'powershell.exe' -ErrorAction Stop).Source
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX CORE 1.0.10 SECRET BRIDGE HOTFIX S1' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("Dynomax root: {0}" -f $dynomaxRoot) -ForegroundColor Gray
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor Gray
    Write-Host 'Database change: NONE' -ForegroundColor Green

    Assert-DynomaxManifestFiles -Root $payloadRoot -Manifest $manifest
    Invoke-DynomaxNativeStep -Name 'Complete patch Windows PowerShell 5.1 parser gate' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$validatorPath,'-RootPath',$patchDirectory)
    Invoke-DynomaxNativeStep -Name 'Payload secret-bridge contract checks' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$contractPath,'-SourceRoot',$payloadRoot,'-AssertNoSqlFiles')

    $alreadyInstalled = $true
    foreach ($entry in @($manifest.files)) {
        $destination = Join-Path $dynomaxRoot (([string]$entry.path -replace '/', '\\'))
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or (Get-DynomaxFileSha256 -Path $destination) -ne ([string]$entry.sha256).ToLowerInvariant()) {
            $alreadyInstalled = $false
            break
        }
    }

    if ($alreadyInstalled) {
        Write-Host 'Dynomax Core 1.0.10 secret bridge S1 is already installed with the exact packaged bytes.' -ForegroundColor Green
    } else {
        $backupRoot = Join-Path $patchDirectory ('Backup\' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))
        [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
        $backupEntries = @()
        foreach ($entry in @($manifest.files)) {
            $relative = [string]$entry.path
            $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
            $existed = Test-Path -LiteralPath $destination -PathType Leaf
            if ($existed) {
                $backup = Join-Path $backupRoot ($relative -replace '/', '\\')
                [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backup)) | Out-Null
                Copy-Item -LiteralPath $destination -Destination $backup -Force
            }
            $backupEntries += [ordered]@{path=$relative;existed=[bool]$existed}
        }
        $backupManifest = [ordered]@{
            schemaVersion=1
            patchVersion='1.0.10-S1'
            createdAtUtc=[DateTime]::UtcNow.ToString('o')
            dynomaxRoot=$dynomaxRoot
            files=$backupEntries
        }
        $backupManifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $backupRoot 'backup-manifest.json') -Encoding UTF8
        $activeBackupRoot = $backupRoot

        foreach ($entry in @($manifest.files)) {
            $relative = [string]$entry.path
            $source = Join-Path $payloadRoot ($relative -replace '/', '\\')
            $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Force
            Write-Host ("Updated {0}" -f $relative) -ForegroundColor Gray
        }
        Write-Host ("Rollback backup: {0}" -f $backupRoot) -ForegroundColor Cyan
    }

    Assert-DynomaxManifestFiles -Root $dynomaxRoot -Manifest $manifest
    Invoke-DynomaxNativeStep -Name 'Installed secret-bridge contract checks' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$contractPath,'-SourceRoot',$dynomaxRoot)
    Invoke-DynomaxNativeStep -Name 'Installed modified-file parser gate' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$validatorPath,'-RootPath',$dynomaxRoot,'-ManifestPath',$manifestPath)
    Invoke-DynomaxNativeStep -Name 'Installed Core parser gate' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$validatorPath,'-RootPath',(Join-Path $dynomaxRoot 'Core'))

    $receipt = [ordered]@{
        schemaVersion=1
        patchVersion='1.0.10-S1'
        installedAtUtc=[DateTime]::UtcNow.ToString('o')
        dynomaxRoot=$dynomaxRoot
        databaseChange='None'
        manifestSha256=Get-DynomaxFileSha256 -Path $manifestPath
        files=$manifest.files
    }
    $receipt | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $patchDirectory 'InstalledReceipt.json') -Encoding UTF8
    Write-Host ''
    Write-Host 'Dynomax Core 1.0.10 secret bridge S1 installed successfully.' -ForegroundColor Green
    Write-Host 'No SQL or database migration was executed.' -ForegroundColor Green
    Write-Host 'No workflow was started automatically.' -ForegroundColor Green
    $exitCode = 0
} catch {
    $failure = $_
    if ($activeBackupRoot) {
        try {
            Restore-DynomaxBackup -BackupRoot $activeBackupRoot
            Write-Host 'The pre-patch files were restored automatically.' -ForegroundColor Yellow
        } catch {
            Write-Host ("Automatic rollback also failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    }
    Write-Host ''
    Write-Host 'DYNOMAX CORE 1.0.10 SECRET BRIDGE S1 PATCH FAILED' -ForegroundColor Red
    Write-Host ("Message: {0}" -f $failure.Exception.Message) -ForegroundColor Yellow
    if ($failure.InvocationInfo) { Write-Host ("Line: {0}" -f $failure.InvocationInfo.ScriptLineNumber) -ForegroundColor Yellow }
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor Cyan
    $exitCode = 1
} finally {
    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
}
exit $exitCode
