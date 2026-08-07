[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$patchDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
$dynomaxRoot = Split-Path -Parent (Split-Path -Parent $patchDirectory)
$payloadRoot = Join-Path $patchDirectory 'Payload'
$manifestPath = Join-Path $patchDirectory 'PATCH_MANIFEST.json'
$validatorPath = Join-Path $patchDirectory 'Validate-ExecutableScripts.ps1'
$contractPath = Join-Path $patchDirectory 'Test-ExecutionPolicyPatch.ps1'
$robotContractPath = Join-Path $patchDirectory 'Test-RobotRuntimePatch.ps1'
$logRoot = Join-Path $dynomaxRoot 'Logs\Patches\1.0.11'
$backupBase = Join-Path $dynomaxRoot 'Backups\Core-1.0.11'
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($backupBase) | Out-Null
$logPath = Join-Path $logRoot ('Dynomax-Core-1.0.11-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '.log')
$transcriptStarted = $false
$activeBackupRoot = $null
$exitCode = 1

function Get-DynomaxFileSha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-DynomaxUtf8NoBom {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Content)
    [System.IO.File]::WriteAllText($Path,$Content,(New-Object System.Text.UTF8Encoding($false)))
}

function Assert-DynomaxSafeRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '(^|[\\/])\.\.([\\/]|$)' -or
        $RelativePath -match '^[A-Za-z]:') {
        throw "Unsafe manifest path '$RelativePath'."
    }
}

function Assert-DynomaxManifestFiles {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)]$Manifest)
    foreach ($entry in @($Manifest.files)) {
        $relative = [string]$entry.path
        Assert-DynomaxSafeRelativePath -RelativePath $relative
        $path = Join-Path $Root ($relative -replace '/', '\\')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Manifest file is missing: $path" }
        $actualHash = Get-DynomaxFileSha256 -Path $path
        if ($actualHash -ne ([string]$entry.sha256).ToLowerInvariant()) { throw "SHA-256 mismatch for '$relative'." }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$entry.length) { throw "Length mismatch for '$relative'." }
    }
}

function Invoke-DynomaxNativeStep {
    param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string]$Executable,[Parameter(Mandatory)][string[]]$Arguments)
    Write-Host ("[Dynomax] START {0}" -f $Name) -ForegroundColor Cyan
    & $Executable @Arguments
    $code = [int]$LASTEXITCODE
    Write-Host ("[Dynomax] END {0}; exit {1}" -f $Name,$code) -ForegroundColor DarkGray
    if ($code -ne 0) { throw "$Name exited with code $code." }
}

function New-DynomaxBackup {
    param([Parameter(Mandatory)]$Manifest)
    $backupRoot = Join-Path $backupBase ([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))
    [System.IO.Directory]::CreateDirectory($backupRoot) | Out-Null
    $entries = @()
    $paths = @($Manifest.files | ForEach-Object { [string]$_.path }) + @('dynomax.json')
    foreach ($relative in $paths | Select-Object -Unique) {
        Assert-DynomaxSafeRelativePath -RelativePath $relative
        $source = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
        $existed = Test-Path -LiteralPath $source -PathType Leaf
        if ($existed) {
            $backup = Join-Path $backupRoot ($relative -replace '/', '\\')
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backup)) | Out-Null
            Copy-Item -LiteralPath $source -Destination $backup -Force
        }
        $entries += [pscustomobject]@{ path=$relative; existed=[bool]$existed }
    }
    $backupManifest = [ordered]@{
        schemaVersion = 1
        patchVersion = '1.0.11'
        createdAtUtc = [DateTime]::UtcNow.ToString('o')
        dynomaxRoot = $dynomaxRoot
        files = $entries
    }
    Write-DynomaxUtf8NoBom -Path (Join-Path $backupRoot 'backup-manifest.json') -Content ($backupManifest | ConvertTo-Json -Depth 20)
    return $backupRoot
}

function Restore-DynomaxBackup {
    param([Parameter(Mandatory)][string]$BackupRoot)
    $backupManifestPath = Join-Path $BackupRoot 'backup-manifest.json'
    if (-not (Test-Path -LiteralPath $backupManifestPath -PathType Leaf)) { throw "Backup manifest was not found at '$backupManifestPath'." }
    $backupManifest = [System.IO.File]::ReadAllText($backupManifestPath) | ConvertFrom-Json
    foreach ($entry in @($backupManifest.files)) {
        $relative = [string]$entry.path
        Assert-DynomaxSafeRelativePath -RelativePath $relative
        $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
        if ([bool]$entry.existed) {
            $source = Join-Path $BackupRoot ($relative -replace '/', '\\')
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Backup file is missing: $source" }
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }
        elseif (Test-Path -LiteralPath $destination -PathType Leaf) {
            Remove-Item -LiteralPath $destination -Force
        }
    }
}

try {
    Start-Transcript -LiteralPath $logPath -Force | Out-Null
    $transcriptStarted = $true
    $configPath = Join-Path $dynomaxRoot 'dynomax.json'
    $versionPath = Join-Path $dynomaxRoot 'VERSION.txt'
    foreach ($required in @($configPath,$versionPath,$payloadRoot,$manifestPath,$validatorPath,$contractPath,$robotContractPath)) {
        if (-not (Test-Path -LiteralPath $required)) { throw "Required component is missing: $required" }
    }

    $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    if ([string]$manifest.patchVersion -ne '1.0.11') { throw 'Patch manifest version is not 1.0.11.' }
    $currentVersion = [System.IO.File]::ReadAllText($versionPath).Trim()
    if (@($manifest.acceptedInstalledVersions) -notcontains $currentVersion) {
        throw "Dynomax Core 1.0.10 or 1.0.11 is required. Current version: $currentVersion"
    }

    $windowsPowerShell = (Get-Command 'powershell.exe' -ErrorAction Stop).Source
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX CORE 1.0.11 R4 R2 ROBOT RUNTIME HOTFIX' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ("Dynomax root: {0}" -f $dynomaxRoot) -ForegroundColor Gray
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor Gray
    Write-Host 'Database change: NONE' -ForegroundColor Green

    Assert-DynomaxManifestFiles -Root $payloadRoot -Manifest $manifest
    Invoke-DynomaxNativeStep -Name 'Packaged PowerShell parser gate' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$validatorPath,'-RootPath',$payloadRoot,'-ManifestPath',$manifestPath)
    Invoke-DynomaxNativeStep -Name 'Packaged execution-policy contract checks' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$contractPath,'-SourceRoot',$payloadRoot,'-AssertNoSqlFiles')
    Invoke-DynomaxNativeStep -Name 'Packaged Robot runtime contract checks' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$robotContractPath,'-SourceRoot',$payloadRoot,'-DynomaxRoot',$dynomaxRoot)

    $config = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
    $currentFrameworkVersion = if ($config.PSObject.Properties.Name -contains 'frameworkVersion') { [string]$config.frameworkVersion } else { '' }
    $alreadyInstalled = ($currentFrameworkVersion -eq '1.0.11')
    foreach ($entry in @($manifest.files)) {
        $destination = Join-Path $dynomaxRoot (([string]$entry.path -replace '/', '\\'))
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf) -or
            (Get-DynomaxFileSha256 -Path $destination) -ne ([string]$entry.sha256).ToLowerInvariant()) {
            $alreadyInstalled = $false
            break
        }
    }

    if ($alreadyInstalled) {
        Write-Host 'Dynomax Core 1.0.11 is already installed with the exact packaged bytes.' -ForegroundColor Green
    }
    else {
        $activeBackupRoot = New-DynomaxBackup -Manifest $manifest
        foreach ($entry in @($manifest.files)) {
            $relative = [string]$entry.path
            $source = Join-Path $payloadRoot ($relative -replace '/', '\\')
            $destination = Join-Path $dynomaxRoot ($relative -replace '/', '\\')
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Force
            Write-Host ("Updated {0}" -f $relative) -ForegroundColor Gray
        }

        $config = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
        if ($config.PSObject.Properties.Name -contains 'frameworkVersion') {
            $config.frameworkVersion = '1.0.11'
        }
        else {
            $config | Add-Member -NotePropertyName frameworkVersion -NotePropertyValue '1.0.11'
        }
        Write-DynomaxUtf8NoBom -Path $configPath -Content ($config | ConvertTo-Json -Depth 100)
        Write-Host ("Rollback backup: {0}" -f $activeBackupRoot) -ForegroundColor Cyan
    }

    Assert-DynomaxManifestFiles -Root $dynomaxRoot -Manifest $manifest
    $installedConfig = [System.IO.File]::ReadAllText($configPath) | ConvertFrom-Json
    if ([string]$installedConfig.frameworkVersion -ne '1.0.11') { throw 'Installed dynomax.json frameworkVersion is not 1.0.11.' }
    if ([System.IO.File]::ReadAllText($versionPath).Trim() -ne '1.0.11') { throw 'Installed VERSION.txt is not 1.0.11.' }
    Invoke-DynomaxNativeStep -Name 'Installed execution-policy contract checks' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$contractPath,'-SourceRoot',$dynomaxRoot,'-ConfigPath',$configPath)
    Invoke-DynomaxNativeStep -Name 'Installed modified-file parser gate' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$validatorPath,'-RootPath',$dynomaxRoot,'-ManifestPath',$manifestPath)
    Invoke-DynomaxNativeStep -Name 'Installed Robot runtime contract checks' -Executable $windowsPowerShell -Arguments @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$robotContractPath,'-SourceRoot',$dynomaxRoot,'-DynomaxRoot',$dynomaxRoot)

    $receipt = [ordered]@{
        schemaVersion = 1
        patchVersion = '1.0.11'
        patchRevision = 'R4-R2'
        installedAtUtc = [DateTime]::UtcNow.ToString('o')
        dynomaxRoot = $dynomaxRoot
        databaseChange = 'None'
        backupRoot = $activeBackupRoot
        manifestSha256 = Get-DynomaxFileSha256 -Path $manifestPath
        files = $manifest.files
    }
    Write-DynomaxUtf8NoBom -Path (Join-Path $patchDirectory 'InstalledReceipt.json') -Content ($receipt | ConvertTo-Json -Depth 30)
    Write-Host ''
    Write-Host 'Dynomax Core 1.0.11 installed successfully.' -ForegroundColor Green
    Write-Host 'R4 R2 Robot runtime hotfix installed successfully.' -ForegroundColor Green
    Write-Host 'No SQL or database migration was executed.' -ForegroundColor Green
    Write-Host 'No Workflow was started automatically.' -ForegroundColor Green
    $exitCode = 0
}
catch {
    $failure = $_
    if ($activeBackupRoot) {
        try {
            Restore-DynomaxBackup -BackupRoot $activeBackupRoot
            Write-Host 'The pre-install Core files and dynomax.json were restored automatically.' -ForegroundColor Yellow
        }
        catch {
            Write-Host ("Automatic rollback also failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        }
    }
    Write-Host ''
    Write-Host 'DYNOMAX CORE 1.0.11 INSTALL FAILED' -ForegroundColor Red
    Write-Host ("Message: {0}" -f $failure.Exception.Message) -ForegroundColor Yellow
    if ($failure.InvocationInfo) { Write-Host ("Line: {0}" -f $failure.InvocationInfo.ScriptLineNumber) -ForegroundColor Yellow }
    Write-Host ("Transcript: {0}" -f $logPath) -ForegroundColor Cyan
    $exitCode = 1
}
finally {
    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
}
exit $exitCode
