[CmdletBinding()]
param([string]$DynomaxConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = if ($DynomaxConfigPath) {
    Split-Path -Parent $DynomaxConfigPath
}
else {
    $current = [System.IO.Path]::GetFullPath($PSScriptRoot)
    while ($current -and -not (Test-Path (Join-Path $current 'dynomax.json'))) {
        $parent = Split-Path -Parent $current
        if ($parent -eq $current) { break }
        $current = $parent
    }
    $current
}

if (-not $root -or -not (Test-Path (Join-Path $root 'dynomax.json'))) {
    throw 'Dynomax root not found.'
}

. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Process.ps1')
. (Join-Path $root 'Core\Results\Dynomax.Results.ps1')

if (-not $DynomaxConfigPath) { $DynomaxConfigPath = Join-Path $root 'dynomax.json' }
$config = Read-DynomaxJson -Path $DynomaxConfigPath
$selfTestConfigPath = Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.frameworkSelfTestConfig
$selfTestConfig = Read-DynomaxJson -Path $selfTestConfigPath
$databaseConfig = Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig = $databaseConfig.sql
$prerequisiteConfig = Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.prerequisiteConfig)
$python = Resolve-DynomaxCommand -Candidates @($prerequisiteConfig.pythonCommandCandidates)
if (-not $python) { throw 'Python was not found. Run prerequisite setup.' }

$validationRunId = [Guid]::NewGuid()
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
$runDirectory = Ensure-DynomaxDirectory -Path (Join-Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.tempRuns) ("FrameworkSelfTest-{0}" -f $timestamp))
$resultDirectory = Ensure-DynomaxDirectory -Path (Join-Path $runDirectory 'robot-result')
$fixturePath = Join-Path $runDirectory 'dynomax-self-test.html'
$consoleLog = Join-Path $runDirectory 'robot-console.log'
$status = 'ERROR'
$summary = 'Dynomax framework self-test did not complete.'
$processResult = $null
$connection = $null
$artifactIngestionSucceeded = $true

function Add-DynomaxFrameworkValidationArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ArtifactType
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -gt [long]$selfTestConfig.maximumSqlArtifactBytes) { return }

    [byte[]]$original = [System.IO.File]::ReadAllBytes($Path)
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $memory = New-Object System.IO.MemoryStream
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($memory,[System.IO.Compression.CompressionMode]::Compress,$true)
        try { $gzip.Write($original,0,$original.Length) } finally { $gzip.Dispose() }
        [byte[]]$compressed = $memory.ToArray()
    }
    finally { $memory.Dispose() }

    $artifactConnection = Open-DynomaxConnection -SqlConfig $sqlConfig
    try {
        $contentIdText = Invoke-DynomaxSqlScalar -Connection $artifactConnection -CommandText 'SELECT CONVERT(nvarchar(36),ArtifactContentId) FROM dmx.ArtifactContent WHERE Sha256=@Sha256;' -Parameters @{ '@Sha256' = $hash }
        if ($contentIdText) {
            $contentId = [Guid]$contentIdText
        }
        else {
            $contentId = [Guid]::NewGuid()
            [void](Invoke-DynomaxSqlNonQuery -Connection $artifactConnection -CommandText @'
INSERT INTO dmx.ArtifactContent(ArtifactContentId,Sha256,OriginalLength,StoredLength,CompressionType,Content,CreatedAtUtc)
VALUES(@Id,@Sha256,@OriginalLength,@StoredLength,'GZip',@Content,SYSUTCDATETIME());
'@ -Parameters @{ '@Id' = $contentId; '@Sha256' = $hash; '@OriginalLength' = [long]$original.LongLength; '@StoredLength' = [long]$compressed.LongLength; '@Content' = $compressed })
        }

        [void](Invoke-DynomaxSqlNonQuery -Connection $artifactConnection -CommandText @'
INSERT INTO dmx.FrameworkValidationArtifact(FrameworkValidationArtifactId,ValidationRunId,ArtifactContentId,ArtifactType,OriginalFileName,MimeType,CreatedAtUtc)
VALUES(NEWID(),@ValidationRunId,@ArtifactContentId,@ArtifactType,@OriginalFileName,@MimeType,SYSUTCDATETIME());
'@ -Parameters @{ '@ValidationRunId' = $validationRunId; '@ArtifactContentId' = $contentId; '@ArtifactType' = $ArtifactType; '@OriginalFileName' = $file.Name; '@MimeType' = (Get-DynomaxMimeType -Path $Path) })
    }
    finally { $artifactConnection.Dispose() }
}

try {
    $connection = Open-DynomaxConnection -SqlConfig $sqlConfig
    [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
INSERT INTO dmx.FrameworkValidationRun(ValidationRunId,FrameworkVersion,MachineName,ValidationType,Status,StartedAtUtc)
VALUES(@ValidationRunId,@FrameworkVersion,@MachineName,@ValidationType,'RUNNING',SYSUTCDATETIME());
'@ -Parameters @{ '@ValidationRunId' = $validationRunId; '@FrameworkVersion' = [string]$config.frameworkVersion; '@MachineName' = $env:COMPUTERNAME; '@ValidationType' = [string]$selfTestConfig.validationType })
    $connection.Dispose()
    $connection = $null

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX FRAMEWORK SELF-TEST: Prerequisites' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    & (Join-Path $root 'Config-And-Setup\01-Prerequisites\Invoke-PrerequisiteSetup.ps1') -DynomaxConfigPath $DynomaxConfigPath -CheckOnly

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX FRAMEWORK SELF-TEST: Database and schema' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    & (Join-Path $root 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1') -DynomaxConfigPath $DynomaxConfigPath

    $html = @'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Dynomax self-test</title></head>
<body><main id="dynomax-self-test" data-dynomax-state="ready">Dynomax local browser self-test</main></body>
</html>
'@
    [System.IO.File]::WriteAllText($fixturePath,$html,(New-Object System.Text.UTF8Encoding($false)))
    $fixtureUri = (New-Object -TypeName System.Uri -ArgumentList ([System.IO.Path]::GetFullPath($fixturePath))).AbsoluteUri
    $suitePath = Join-Path $PSScriptRoot 'framework-self-test.robot'
    if (-not (Test-Path -LiteralPath $suitePath -PathType Leaf)) { throw 'Framework self-test Robot suite is missing.' }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host 'DYNOMAX FRAMEWORK SELF-TEST: Local browser engine' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    $arguments = @(
        '-B','-m','robot',
        '--outputdir',$resultDirectory,
        '--output','output.xml',
        '--log','log.html',
        '--report','report.html',
        '--variable',("SELF_TEST_URL:{0}" -f $fixtureUri),
        '--variable',("SELF_TEST_BROWSER:{0}" -f [string]$selfTestConfig.browser),
        '--variable',("SELF_TEST_HEADLESS:{0}" -f (ConvertTo-DynomaxBooleanString $selfTestConfig.headless)),
        $suitePath
    )
    $processResult = Invoke-DynomaxProcess -FilePath $python -Arguments $arguments -WorkingDirectory $runDirectory -TimeoutSeconds ([int]$selfTestConfig.timeoutSeconds) -ConsoleLogPath $consoleLog -Environment @{ 'PYTHONDONTWRITEBYTECODE' = '1' } -StreamOutput -HeartbeatSeconds 15 -DisplayName 'Dynomax local browser self-test'
    if ($processResult.ExitCode -ne 0) { throw "Local browser self-test failed with exit code $($processResult.ExitCode)." }

    foreach ($required in @('output.xml','log.html','report.html')) {
        $requiredPath = Join-Path $resultDirectory $required
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) { throw "Local browser self-test did not produce $required." }
    }

    $status = 'PASS'
    $summary = 'Dynomax generic framework, SQL persistence, Robot Framework Browser and local Chromium execution passed. No project or external website was used.'
}
catch {
    $status = 'ERROR'
    $summary = $_.Exception.Message
    Write-DynomaxLog -Message $summary -Level Error
}
finally {
    if ($connection) { $connection.Dispose() }

    if ([bool]$selfTestConfig.storeArtifactsInSql) {
        $artifactCandidates = @(
            @{ Path = $consoleLog; Type = 'FrameworkSelfTestConsole' },
            @{ Path = (Join-Path $resultDirectory 'output.xml'); Type = 'FrameworkSelfTestRobotOutput' },
            @{ Path = (Join-Path $resultDirectory 'log.html'); Type = 'FrameworkSelfTestRobotLog' },
            @{ Path = (Join-Path $resultDirectory 'report.html'); Type = 'FrameworkSelfTestRobotReport' }
        )
        Get-ChildItem -LiteralPath $resultDirectory -Filter '*.png' -File -ErrorAction SilentlyContinue | ForEach-Object {
            $artifactCandidates += @{ Path = $_.FullName; Type = 'FrameworkSelfTestScreenshot' }
        }
        foreach ($candidate in $artifactCandidates) {
            try { Add-DynomaxFrameworkValidationArtifact -Path $candidate.Path -ArtifactType $candidate.Type }
            catch {
                $artifactIngestionSucceeded = $false
                Write-DynomaxLog -Message ("Framework self-test artifact ingestion failed for '{0}': {1}" -f $candidate.Path,$_.Exception.Message) -Level Warning
            }
        }
    }

    $result = [ordered]@{
        schemaVersion = 1
        validationRunId = [string]$validationRunId
        frameworkVersion = [string]$config.frameworkVersion
        validationType = [string]$selfTestConfig.validationType
        projectKey = $null
        targetWebsite = $null
        usedExternalWebsite = $false
        status = $status
        summary = $summary
        machine = $env:COMPUTERNAME
        completedAtUtc = [DateTime]::UtcNow.ToString('o')
        artifactIngestionSucceeded = $artifactIngestionSucceeded
    }
    $resultJson = $result | ConvertTo-Json -Depth 20 -Compress
    try {
        $finalConnection = Open-DynomaxConnection -SqlConfig $sqlConfig
        try {
            [void](Invoke-DynomaxSqlNonQuery -Connection $finalConnection -CommandText @'
UPDATE dmx.FrameworkValidationRun
SET Status=@Status,EndedAtUtc=SYSUTCDATETIME(),Summary=@Summary,ResultJson=@ResultJson
WHERE ValidationRunId=@ValidationRunId;
'@ -Parameters @{ '@Status' = $status; '@Summary' = $summary; '@ResultJson' = $resultJson; '@ValidationRunId' = $validationRunId })
        }
        finally { $finalConnection.Dispose() }
    }
    catch {
        $artifactIngestionSucceeded = $false
        Write-DynomaxLog -Message ("Could not persist final framework validation result: {0}" -f $_.Exception.Message) -Level Warning
    }

    if ($status -eq 'PASS' -and $artifactIngestionSucceeded -and [bool]$selfTestConfig.deleteTemporaryRunAfterSuccessfulIngestion) {
        try { Remove-Item -LiteralPath $runDirectory -Recurse -Force }
        catch { Write-DynomaxLog -Message ("Could not remove framework self-test directory: {0}" -f $_.Exception.Message) -Level Warning }
    }
}

Write-Host ''
Write-Host ("Dynomax Framework Validation ID: {0}" -f $validationRunId) -ForegroundColor Cyan
Write-Host ("Overall Status: {0}" -f $status) -ForegroundColor $(if ($status -eq 'PASS') { 'Green' } else { 'Red' })
Write-Host $summary -ForegroundColor $(if ($status -eq 'PASS') { 'Green' } else { 'Yellow' })
if ($status -eq 'PASS') { exit 0 }
exit 1
