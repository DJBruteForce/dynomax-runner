[CmdletBinding()]
param(
    [string]$DynomaxRoot = 'C:\Dynomax'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$fixtureRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$fixtureManifestPath = Join-Path $fixtureRoot 'FIXTURE_MANIFEST.json'
$fixtureProjectSource = Join-Path $fixtureRoot 'FixtureProject'
$fixtureProjectFolderName = 'Dynomax-Core-1.0.9-Exact-Version-Acceptance-R1'
$fixtureProjectDestination = Join-Path $DynomaxRoot ('Project-Setup\' + $fixtureProjectFolderName)
$projectKey = 'dynomax-core-109-exact-version-acceptance-r1'
$actionKey = 'dynomax.core.exact-version.probe'
$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
$resultRoot = Join-Path $fixtureRoot ('Results\' + $timestamp)
$consoleLogPath = Join-Path $resultRoot 'FixtureConsole.log'
$reportJsonPath = Join-Path $resultRoot 'AcceptanceReport.json'
$reportMarkdownPath = Join-Path $resultRoot 'AcceptanceReport.md'
$transcriptPath = Join-Path $resultRoot 'FixtureTranscript.log'
$transcriptStarted = $false
$checks = New-Object System.Collections.Generic.List[object]
$details = [ordered]@{}
$failureMessage = $null
$finalStatus = 'FAIL'
$finalZipPath = $null

function Write-FixtureStep {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = '[Fixture] ' + $Message
    Write-Host $line -ForegroundColor Cyan
    [System.IO.File]::AppendAllText($consoleLogPath, $line + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Add-FixtureCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [Parameter(Mandatory = $true)][string]$Details
    )
    $entry = [ordered]@{
        name = $Name
        passed = $Passed
        details = $Details
        checkedAtUtc = [DateTime]::UtcNow.ToString('o')
    }
    $checks.Add([pscustomobject]$entry)
    if ($Passed) {
        Write-Host ('[PASS] ' + $Name + ' - ' + $Details) -ForegroundColor Green
    }
    else {
        Write-Host ('[FAIL] ' + $Name + ' - ' + $Details) -ForegroundColor Red
    }
}

function Assert-FixtureCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$PassDetails,
        [Parameter(Mandatory = $true)][string]$FailDetails
    )
    if ($Condition) {
        Add-FixtureCheck -Name $Name -Passed $true -Details $PassDetails
        return
    }
    Add-FixtureCheck -Name $Name -Passed $false -Details $FailDetails
    throw $FailDetails
}

function Get-FixtureSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-FixtureJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json)
}

function Write-FixtureJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if ($parent) { [System.IO.Directory]::CreateDirectory($parent) | Out-Null }
    $json = $Value | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Test-SafeRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $false }
    if ($Path -match '(^|[\\/])\.\.([\\/]|$)') { return $false }
    return $true
}

function Assert-FixturePackageManifest {
    $manifest = Read-FixtureJson -Path $fixtureManifestPath
    Assert-FixtureCheck -Name 'Fixture manifest version' -Condition ([string]$manifest.fixtureVersion -eq '1.0.1') -PassDetails 'Fixture manifest version 1.0.1 is present.' -FailDetails 'Fixture manifest version is not 1.0.1.'
    foreach ($file in @($manifest.files)) {
        $relative = [string]$file.path
        if (-not (Test-SafeRelativePath -Path $relative)) { throw "Unsafe fixture manifest path '$relative'." }
        $path = Join-Path $fixtureRoot ($relative -replace '/', '\\')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Fixture file is missing: $path" }
        $actualHash = Get-FixtureSha256 -Path $path
        if ($actualHash -ne ([string]$file.sha256).ToLowerInvariant()) { throw "Fixture SHA-256 mismatch for '$relative'." }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$file.length) { throw "Fixture length mismatch for '$relative'." }
    }
    Add-FixtureCheck -Name 'Fixture file integrity' -Passed $true -Details ("Verified {0} packaged fixture files." -f @($manifest.files).Count)
}

function Assert-WindowsPowerShellScriptsParse {
    $scriptFiles = @(Get-ChildItem -LiteralPath $fixtureRoot -Filter '*.ps1' -File -Recurse | Where-Object { $_.FullName -notlike (Join-Path $resultRoot '*') })
    foreach ($scriptFile in $scriptFiles) {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$errors)
        if (@($errors).Count -gt 0) {
            $text = @($errors | ForEach-Object { $_.Message }) -join '; '
            throw "PowerShell parser failure for '$($scriptFile.FullName)': $text"
        }
    }
    Add-FixtureCheck -Name 'Windows PowerShell parser gate' -Passed $true -Details ("Parsed {0} fixture PowerShell files without errors." -f $scriptFiles.Count)
}

function Install-FixtureProjectFolder {
    if (Test-Path -LiteralPath $fixtureProjectDestination -PathType Container) {
        $sentinel = Join-Path $fixtureProjectDestination 'FIXTURE_PROJECT.json'
        if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
            throw "Refusing to replace existing folder without fixture sentinel: $fixtureProjectDestination"
        }
        $existing = Read-FixtureJson -Path $sentinel
        if ([string]$existing.projectKey -ne $projectKey) {
            throw "Refusing to replace existing fixture folder with unexpected project key '$($existing.projectKey)'."
        }
        Remove-Item -LiteralPath $fixtureProjectDestination -Recurse -Force
    }
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $fixtureProjectDestination)) | Out-Null
    Copy-Item -LiteralPath $fixtureProjectSource -Destination $fixtureProjectDestination -Recurse -Force
    Add-FixtureCheck -Name 'Fixture project installation' -Passed $true -Details ("Installed isolated fixture project at {0}." -f $fixtureProjectDestination)
}

function Get-WorkflowPaths {
    return [ordered]@{
        exact = Join-Path $fixtureProjectDestination 'Project-Workflow\Sessions\0100-Exact-Version-Pinned-V1'
        legacy = Join-Path $fixtureProjectDestination 'Project-Workflow\Sessions\0200-Legacy-Current-Fallback'
        stale = Join-Path $fixtureProjectDestination 'Project-Workflow\Sessions\0300-Stale-Pinned-V1'
    }
}

function Get-SqlRunRecord {
    param(
        [Parameter(Mandatory = $true)]$SqlConfig,
        [Parameter(Mandatory = $true)][Guid]$RunId
    )
    $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
    try {
        $table = Invoke-DynomaxSqlRows -Connection $connection -CommandText @'
SELECT tr.RunId,tr.WorkflowVersionId,tr.Status AS RunStatus,
       ar.ActionVersionId,ar.Status AS ActionStatus,ar.ActionKey,ar.StepOrder
FROM dmx.TestRun tr
JOIN dmx.ActionRun ar ON ar.RunId=tr.RunId
WHERE tr.RunId=@RunId
ORDER BY ar.StepOrder,ar.StartedAtUtc;
'@ -Parameters @{ '@RunId' = $RunId }
        if ($table.Rows.Count -ne 1) { throw "Expected one action row for run '$RunId', found $($table.Rows.Count)." }
        $row = $table.Rows[0]
        return [pscustomobject]@{
            RunId = [Guid]$row.RunId
            WorkflowVersionId = [Guid]$row.WorkflowVersionId
            RunStatus = [string]$row.RunStatus
            ActionVersionId = $(if ($row.ActionVersionId -is [DBNull]) { [Guid]::Empty } else { [Guid]$row.ActionVersionId })
            ActionStatus = [string]$row.ActionStatus
            ActionKey = [string]$row.ActionKey
            StepOrder = [int]$row.StepOrder
        }
    }
    finally { $connection.Dispose() }
}

function Invoke-FixtureWorkflow {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$WorkflowDirectory,
        [Parameter(Mandatory = $true)][string]$WorkflowId,
        [Parameter(Mandatory = $true)][int]$ExpectedExitCode,
        [Parameter(Mandatory = $true)][string]$ExpectedZipStatus,
        [Parameter(Mandatory = $true)][string]$WindowsPowerShell,
        [Parameter(Mandatory = $true)][string]$ExportsPath
    )
    Write-FixtureStep -Message ("Running {0}." -f $Name)
    $runEvidence = Join-Path $resultRoot $Name
    [System.IO.Directory]::CreateDirectory($runEvidence) | Out-Null
    $stdoutPath = Join-Path $runEvidence 'RunnerConsole.log'
    $started = [DateTime]::UtcNow.AddSeconds(-2)
    $runner = Join-Path $DynomaxRoot 'Core\Invoke-DynomaxWorkflow.ps1'
    $arguments = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-WorkflowDirectory',$WorkflowDirectory)
    $output = & $WindowsPowerShell @arguments 2>&1
    $exitCode = [int]$LASTEXITCODE
    $outputText = @($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $outputText + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host $outputText

    Assert-FixtureCheck -Name ($Name + ' runner exit code') -Condition ($exitCode -eq $ExpectedExitCode) -PassDetails ("Runner exited with expected code {0}." -f $exitCode) -FailDetails ("Runner exit code was {0}; expected {1}." -f $exitCode,$ExpectedExitCode)

    $pattern = 'Dynomax_' + $projectKey + '_' + $WorkflowId + '_*_' + $ExpectedZipStatus + '.zip'
    $zips = @(Get-ChildItem -LiteralPath $ExportsPath -Filter $pattern -File | Where-Object { $_.LastWriteTimeUtc -ge $started } | Sort-Object LastWriteTimeUtc -Descending)
    if ($zips.Count -eq 0) {
        $zips = @(Get-ChildItem -LiteralPath $ExportsPath -Filter $pattern -File | Sort-Object LastWriteTimeUtc -Descending)
    }
    if ($zips.Count -eq 0) { throw "No result ZIP matched '$pattern'." }
    $zip = $zips[0]
    $copiedZip = Join-Path $runEvidence $zip.Name
    Copy-Item -LiteralPath $zip.FullName -Destination $copiedZip -Force
    $extractPath = Join-Path $runEvidence 'ExtractedResult'
    if (Test-Path -LiteralPath $extractPath) { Remove-Item -LiteralPath $extractPath -Recurse -Force }
    [System.IO.Directory]::CreateDirectory($extractPath) | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($copiedZip, $extractPath)

    $manifestPath = Join-Path $extractPath 'WorkflowManifest.json'
    $actionsPath = Join-Path $extractPath 'ActionResults.json'
    $summaryPath = Join-Path $extractPath 'RunSummary.json'
    foreach ($required in @($manifestPath,$actionsPath,$summaryPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required result evidence is missing: $required" }
    }

    return [pscustomobject]@{
        Name = $Name
        ExitCode = $exitCode
        ResultZip = $copiedZip
        ExtractedPath = $extractPath
        WorkflowManifest = Read-FixtureJson -Path $manifestPath
        ActionResults = Read-FixtureJson -Path $actionsPath
        RunSummary = Read-FixtureJson -Path $summaryPath
    }
}

function Add-ReportDetail {
    param([Parameter(Mandatory = $true)][string]$Name,[Parameter(Mandatory = $true)]$Value)
    $details[$Name] = $Value
}

[System.IO.Directory]::CreateDirectory($resultRoot) | Out-Null
[System.IO.File]::WriteAllText($consoleLogPath, '', (New-Object System.Text.UTF8Encoding($false)))

try {
    Start-Transcript -LiteralPath $transcriptPath -Force | Out-Null
    $transcriptStarted = $true
    Write-FixtureStep -Message 'Starting Dynomax Core 1.0.9 exact-version runtime acceptance.'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Assert-FixturePackageManifest
    Assert-WindowsPowerShellScriptsParse

    $rootConfigPath = Join-Path $DynomaxRoot 'dynomax.json'
    $versionPath = Join-Path $DynomaxRoot 'VERSION.txt'
    $receiptPath = Join-Path $DynomaxRoot 'Patches\1.0.9\InstalledReceipt.json'
    foreach ($required in @($rootConfigPath,$versionPath,$receiptPath,(Join-Path $DynomaxRoot 'Core\Invoke-DynomaxWorkflow.ps1'))) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required Dynomax file is missing: $required" }
    }

    $coreVersion = [System.IO.File]::ReadAllText($versionPath).Trim()
    Assert-FixtureCheck -Name 'Installed Core version' -Condition ($coreVersion -eq '1.0.9') -PassDetails 'C:\Dynomax\VERSION.txt reports 1.0.9.' -FailDetails ("Expected Core 1.0.9, found '$coreVersion'.")
    $receipt = Read-FixtureJson -Path $receiptPath
    Assert-FixtureCheck -Name 'Installed patch receipt' -Condition ([string]$receipt.patchVersion -eq '1.0.9') -PassDetails 'InstalledReceipt.json confirms patch 1.0.9.' -FailDetails 'InstalledReceipt.json does not confirm patch 1.0.9.'
    Add-ReportDetail -Name 'installedReceiptManifestSha256' -Value ([string]$receipt.manifestSha256)

    $windowsPowerShell = (Get-Command 'powershell.exe' -ErrorAction Stop).Source
    Install-FixtureProjectFolder

    . (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
    . (Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1')
    . (Join-Path $DynomaxRoot 'Core\Catalogue\Dynomax.Catalogue.ps1')

    $config = Read-DynomaxJson -Path $rootConfigPath
    $databaseConfigPath = Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath ([string]$config.paths.databaseConfig)
    $databaseConfig = Read-DynomaxJson -Path $databaseConfigPath
    $sqlConfig = $databaseConfig.sql
    $exportsPath = Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath ([string]$config.paths.exports)

    $projectJsonPath = Join-Path $fixtureProjectDestination 'Project-And-Config\project.json'
    $v1ActionJsonPath = Join-Path $fixtureProjectDestination 'Project-Workflow\Sessions\0100-Exact-Version-Pinned-V1\Payload\0001-Exact-Version-Probe-V1\action.json'
    $v2ActionJsonPath = Join-Path $fixtureProjectDestination 'Project-Library\0001-Exact-Version-Probe-V2\action.json'
    [void](Import-DynomaxProjectDefinition -ProjectJsonPath $projectJsonPath -SqlConfig $sqlConfig)
    $v1ImportedId = Import-DynomaxActionDefinition -ActionJsonPath $v1ActionJsonPath -SqlConfig $sqlConfig
    $v2ImportedId = Import-DynomaxActionDefinition -ActionJsonPath $v2ActionJsonPath -SqlConfig $sqlConfig

    $v1Record = Get-DynomaxActionVersionRecord -SqlConfig $sqlConfig -ProjectKey $projectKey -ActionKey $actionKey -RequestedActionVersion 1
    $v2Record = Get-DynomaxActionVersionRecord -SqlConfig $sqlConfig -ProjectKey $projectKey -ActionKey $actionKey -RequestedActionVersion 2
    $currentRecord = Get-DynomaxActionVersionRecord -SqlConfig $sqlConfig -ProjectKey $projectKey -ActionKey $actionKey
    Assert-FixtureCheck -Name 'Fixture action version 1' -Condition ($null -ne $v1Record -and [int]$v1Record.VersionNumber -eq 1 -and [Guid]$v1Record.ActionVersionId -eq [Guid]$v1ImportedId) -PassDetails ("Imported action v1 as {0}." -f $v1Record.ActionVersionId) -FailDetails 'Fixture action v1 did not resolve to the imported version ID.'
    Assert-FixtureCheck -Name 'Fixture action version 2' -Condition ($null -ne $v2Record -and [int]$v2Record.VersionNumber -eq 2 -and [Guid]$v2Record.ActionVersionId -eq [Guid]$v2ImportedId) -PassDetails ("Imported action v2 as {0}." -f $v2Record.ActionVersionId) -FailDetails 'Fixture action v2 did not resolve to the imported version ID.'
    Assert-FixtureCheck -Name 'Current action version before execution' -Condition ([Guid]$currentRecord.ActionVersionId -eq [Guid]$v2Record.ActionVersionId -and [int]$currentRecord.VersionNumber -eq 2) -PassDetails 'Action v2 is current before any workflow runs.' -FailDetails ("Expected current action v2, found v{0}." -f $currentRecord.VersionNumber)

    $paths = Get-WorkflowPaths
    $exactWorkflowVersionId = Import-DynomaxWorkflowDefinition -WorkflowJsonPath (Join-Path $paths.exact 'workflow.json') -SqlConfig $sqlConfig
    $legacyWorkflowVersionId = Import-DynomaxWorkflowDefinition -WorkflowJsonPath (Join-Path $paths.legacy 'workflow.json') -SqlConfig $sqlConfig
    $staleWorkflowVersionId = Import-DynomaxWorkflowDefinition -WorkflowJsonPath (Join-Path $paths.stale 'workflow.json') -SqlConfig $sqlConfig
    Add-ReportDetail -Name 'fixtureProjectKey' -Value $projectKey
    Add-ReportDetail -Name 'actionVersion1Id' -Value ([string]$v1Record.ActionVersionId)
    Add-ReportDetail -Name 'actionVersion2Id' -Value ([string]$v2Record.ActionVersionId)
    Add-ReportDetail -Name 'exactWorkflowVersionId' -Value ([string]$exactWorkflowVersionId)
    Add-ReportDetail -Name 'legacyWorkflowVersionId' -Value ([string]$legacyWorkflowVersionId)
    Add-ReportDetail -Name 'staleWorkflowVersionId' -Value ([string]$staleWorkflowVersionId)

    $exactRun = Invoke-FixtureWorkflow -Name '01-Pinned-V1' -WorkflowDirectory $paths.exact -WorkflowId 'dynomax.core.109.exact-version.pinned-v1' -ExpectedExitCode 0 -ExpectedZipStatus 'PASS' -WindowsPowerShell $windowsPowerShell -ExportsPath $exportsPath
    $exactAction = @($exactRun.ActionResults.actions)[0]
    $exactManifestAction = @($exactRun.WorkflowManifest.actions)[0]
    $exactRunId = [Guid][string]$exactRun.WorkflowManifest.runId
    $exactSql = Get-SqlRunRecord -SqlConfig $sqlConfig -RunId $exactRunId
    Assert-FixtureCheck -Name 'Pinned workflow executed v1 marker' -Condition ([string]$exactAction.output.marker -eq 'VERSION-1' -and [int]$exactAction.output.probeVersion -eq 1) -PassDetails 'Pinned workflow executed the VERSION-1 implementation.' -FailDetails 'Pinned workflow did not produce the VERSION-1 marker.'
    Assert-FixtureCheck -Name 'Pinned ActionResults version mapping' -Condition ([int]$exactAction.requestedActionVersion -eq 1 -and [int]$exactAction.resolvedActionVersion -eq 1 -and [Guid][string]$exactAction.actionVersionId -eq [Guid]$v1Record.ActionVersionId) -PassDetails 'ActionResults.json identifies requested v1, resolved v1 and the v1 ActionVersionId.' -FailDetails 'ActionResults.json does not identify the exact v1 mapping.'
    Assert-FixtureCheck -Name 'Pinned WorkflowManifest version mapping' -Condition ([bool]$exactRun.WorkflowManifest.exactActionVersionsPinned -and [int]$exactManifestAction.requestedActionVersion -eq 1 -and [int]$exactManifestAction.resolvedActionVersion -eq 1 -and [bool]$exactManifestAction.sourceVerified -and [Guid][string]$exactManifestAction.actionVersionId -eq [Guid]$v1Record.ActionVersionId) -PassDetails 'WorkflowManifest.json confirms pinned and source-verified action v1.' -FailDetails 'WorkflowManifest.json does not confirm exact source-verified action v1.'
    Assert-FixtureCheck -Name 'Pinned SQL workflow version' -Condition ([Guid]$exactSql.WorkflowVersionId -eq [Guid]$exactWorkflowVersionId -and $exactSql.RunStatus -eq 'PASS') -PassDetails 'TestRun points to the exact imported pinned workflow version and is PASS.' -FailDetails 'TestRun does not point to the exact pinned workflow version.'
    Assert-FixtureCheck -Name 'Pinned SQL action version' -Condition ([Guid]$exactSql.ActionVersionId -eq [Guid]$v1Record.ActionVersionId -and $exactSql.ActionStatus -eq 'PASS') -PassDetails 'ActionRun points to action v1 and is PASS.' -FailDetails 'ActionRun does not point to action v1.'

    $currentAfterExact = Get-DynomaxActionVersionRecord -SqlConfig $sqlConfig -ProjectKey $projectKey -ActionKey $actionKey
    Assert-FixtureCheck -Name 'Current version preserved after pinned run' -Condition ([int]$currentAfterExact.VersionNumber -eq 2 -and [Guid]$currentAfterExact.ActionVersionId -eq [Guid]$v2Record.ActionVersionId) -PassDetails 'Executing pinned v1 did not change current v2.' -FailDetails 'Executing pinned v1 changed the current catalogue version.'

    $legacyRun = Invoke-FixtureWorkflow -Name '02-Legacy-Current-V2' -WorkflowDirectory $paths.legacy -WorkflowId 'dynomax.core.109.legacy-current-fallback' -ExpectedExitCode 0 -ExpectedZipStatus 'PASS' -WindowsPowerShell $windowsPowerShell -ExportsPath $exportsPath
    $legacyAction = @($legacyRun.ActionResults.actions)[0]
    $legacyManifestAction = @($legacyRun.WorkflowManifest.actions)[0]
    $legacyRunId = [Guid][string]$legacyRun.WorkflowManifest.runId
    $legacySql = Get-SqlRunRecord -SqlConfig $sqlConfig -RunId $legacyRunId
    Assert-FixtureCheck -Name 'Legacy workflow executed current v2 marker' -Condition ([string]$legacyAction.output.marker -eq 'VERSION-2' -and [int]$legacyAction.output.probeVersion -eq 2) -PassDetails 'Unversioned legacy workflow executed the current VERSION-2 implementation.' -FailDetails 'Legacy workflow did not produce the VERSION-2 marker.'
    Assert-FixtureCheck -Name 'Legacy ActionResults version mapping' -Condition ($null -eq $legacyAction.requestedActionVersion -and [int]$legacyAction.resolvedActionVersion -eq 2 -and [Guid][string]$legacyAction.actionVersionId -eq [Guid]$v2Record.ActionVersionId) -PassDetails 'ActionResults.json retains unversioned fallback and identifies resolved v2.' -FailDetails 'ActionResults.json does not identify the legacy current-version fallback to v2.'
    Assert-FixtureCheck -Name 'Legacy WorkflowManifest version mapping' -Condition (-not [bool]$legacyRun.WorkflowManifest.exactActionVersionsPinned -and $null -eq $legacyManifestAction.requestedActionVersion -and [int]$legacyManifestAction.resolvedActionVersion -eq 2 -and [bool]$legacyManifestAction.sourceVerified -and [Guid][string]$legacyManifestAction.actionVersionId -eq [Guid]$v2Record.ActionVersionId) -PassDetails 'WorkflowManifest.json identifies source-verified current v2 without claiming version pinning.' -FailDetails 'WorkflowManifest.json does not correctly represent legacy current-version fallback.'
    Assert-FixtureCheck -Name 'Legacy SQL workflow version' -Condition ([Guid]$legacySql.WorkflowVersionId -eq [Guid]$legacyWorkflowVersionId -and $legacySql.RunStatus -eq 'PASS') -PassDetails 'Legacy TestRun points to its exact imported workflow version and is PASS.' -FailDetails 'Legacy TestRun does not point to its imported workflow version.'
    Assert-FixtureCheck -Name 'Legacy SQL action version' -Condition ([Guid]$legacySql.ActionVersionId -eq [Guid]$v2Record.ActionVersionId -and $legacySql.ActionStatus -eq 'PASS') -PassDetails 'Legacy ActionRun points to current action v2 and is PASS.' -FailDetails 'Legacy ActionRun does not point to current action v2.'

    $staleRun = Invoke-FixtureWorkflow -Name '03-Stale-Pinned-V1' -WorkflowDirectory $paths.stale -WorkflowId 'dynomax.core.109.stale-pinned-v1' -ExpectedExitCode 1 -ExpectedZipStatus 'STALE' -WindowsPowerShell $windowsPowerShell -ExportsPath $exportsPath
    $staleAction = @($staleRun.ActionResults.actions)[0]
    $staleManifestAction = @($staleRun.WorkflowManifest.actions)[0]
    $staleRunId = [Guid][string]$staleRun.WorkflowManifest.runId
    $staleSql = Get-SqlRunRecord -SqlConfig $sqlConfig -RunId $staleRunId
    $staleOutputEvidence = Join-Path $staleRun.ExtractedPath 'TestEvidence\action-10.json'
    Assert-FixtureCheck -Name 'Stale preflight classification' -Condition ([string]$staleRun.WorkflowManifest.preflight.status -eq 'FAILED' -and [string]$staleRun.WorkflowManifest.preflight.classification -eq 'STALE' -and [string]$staleRun.RunSummary.status -eq 'STALE') -PassDetails 'Pinned v1 without exact source bytes was rejected as STALE.' -FailDetails 'Stale workflow was not classified as STALE.'
    Assert-FixtureCheck -Name 'Stale action was not invoked' -Condition (-not (Test-Path -LiteralPath $staleOutputEvidence -PathType Leaf)) -PassDetails 'No action-10.json output exists; the action was not invoked.' -FailDetails 'Stale workflow produced action output, indicating that the action was invoked.'
    Assert-FixtureCheck -Name 'Stale ActionResults version mapping' -Condition ([int]$staleAction.requestedActionVersion -eq 1 -and [int]$staleAction.resolvedActionVersion -eq 1 -and [Guid][string]$staleAction.actionVersionId -eq [Guid]$v1Record.ActionVersionId -and [string]$staleAction.status -eq 'STALE') -PassDetails 'ActionResults.json ties the STALE result to requested action v1.' -FailDetails 'ActionResults.json does not tie the STALE result to action v1.'
    Assert-FixtureCheck -Name 'Stale WorkflowManifest unresolved source' -Condition ([string]$staleManifestAction.resolutionStatus -eq 'Unresolved' -and -not [bool]$staleManifestAction.sourceVerified -and [int]$staleManifestAction.requestedActionVersion -eq 1) -PassDetails 'WorkflowManifest.json records requested v1 with an unresolved, unverified source.' -FailDetails 'WorkflowManifest.json does not record the stale unresolved source correctly.'
    Assert-FixtureCheck -Name 'Stale SQL workflow version' -Condition ([Guid]$staleSql.WorkflowVersionId -eq [Guid]$staleWorkflowVersionId -and $staleSql.RunStatus -eq 'STALE') -PassDetails 'Stale TestRun points to the exact imported stale workflow version.' -FailDetails 'Stale TestRun does not point to the exact stale workflow version.'
    Assert-FixtureCheck -Name 'Stale SQL action version' -Condition ([Guid]$staleSql.ActionVersionId -eq [Guid]$v1Record.ActionVersionId -and $staleSql.ActionStatus -eq 'STALE') -PassDetails 'Stale ActionRun identifies requested action v1 without execution.' -FailDetails 'Stale ActionRun does not identify requested action v1.'

    Add-ReportDetail -Name 'pinnedRunId' -Value ([string]$exactRunId)
    Add-ReportDetail -Name 'legacyRunId' -Value ([string]$legacyRunId)
    Add-ReportDetail -Name 'staleRunId' -Value ([string]$staleRunId)
    Add-ReportDetail -Name 'pinnedResultZip' -Value $exactRun.ResultZip
    Add-ReportDetail -Name 'legacyResultZip' -Value $legacyRun.ResultZip
    Add-ReportDetail -Name 'staleResultZip' -Value $staleRun.ResultZip

    $finalStatus = 'PASS'
}
catch {
    $failureMessage = $_.Exception.Message
    Write-Host ''
    Write-Host 'DYNOMAX CORE 1.0.9 ACCEPTANCE FAILED' -ForegroundColor Red
    Write-Host ('Message: ' + $failureMessage) -ForegroundColor Yellow
    if ($_.InvocationInfo) { Write-Host ('Line: ' + $_.InvocationInfo.ScriptLineNumber) -ForegroundColor Yellow }
}
finally {
    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch { } }
    $report = [ordered]@{
        schemaVersion = 1
        fixtureVersion = '1.0.1'
        status = $finalStatus
        startedAtUtc = $timestamp
        completedAtUtc = [DateTime]::UtcNow.ToString('o')
        dynomaxRoot = $DynomaxRoot
        databaseClassification = 'Isolated acceptance data through standard Core APIs; read-only SQL verification; no schema change or cleanup deletion.'
        failure = $failureMessage
        details = $details
        checks = $checks.ToArray()
    }
    try { Write-FixtureJson -Value $report -Path $reportJsonPath } catch { }

    $markdown = New-Object System.Collections.Generic.List[string]
    $markdown.Add('# Dynomax Core 1.0.9 exact-version runtime acceptance')
    $markdown.Add('')
    $markdown.Add(('- Status: **{0}**' -f $finalStatus))
    $markdown.Add(('- Completed UTC: {0}' -f [DateTime]::UtcNow.ToString('o')))
    $markdown.Add(('- Dynomax root: `{0}`' -f $DynomaxRoot))
    if ($failureMessage) { $markdown.Add(('- Failure: {0}' -f $failureMessage)) }
    $markdown.Add('')
    $markdown.Add('## Checks')
    $markdown.Add('')
    foreach ($check in $checks) {
        $mark = if ([bool]$check.passed) { 'PASS' } else { 'FAIL' }
        $markdown.Add(('- **{0}** - {1}: {2}' -f $mark,$check.name,$check.details))
    }
    $markdown.Add('')
    $markdown.Add('## Evidence')
    $markdown.Add('')
    $markdown.Add('The package contains each Core result ZIP, extracted `ActionResults.json`, `WorkflowManifest.json`, `RunSummary.json`, runner console output and this acceptance report.')
    try { [System.IO.File]::WriteAllLines($reportMarkdownPath, $markdown.ToArray(), (New-Object System.Text.UTF8Encoding($false))) } catch { }

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $finalZipName = 'Dynomax_Core_1.0.9_ExactVersion_Acceptance_' + $timestamp + '_' + $finalStatus + '.zip'
        $finalZipPath = Join-Path (Split-Path -Parent $resultRoot) $finalZipName
        if (Test-Path -LiteralPath $finalZipPath) { Remove-Item -LiteralPath $finalZipPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($resultRoot, $finalZipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
        Write-Host ''
        Write-Host ('Acceptance evidence ZIP: ' + $finalZipPath) -ForegroundColor Cyan
        try { Set-Clipboard -Path $finalZipPath -ErrorAction Stop } catch { }
    }
    catch {
        Write-Host ('Could not create acceptance evidence ZIP: ' + $_.Exception.Message) -ForegroundColor Yellow
    }

    Write-Host ('Acceptance report: ' + $reportMarkdownPath) -ForegroundColor Cyan
    Write-Host ('Final status: ' + $finalStatus) -ForegroundColor $(if ($finalStatus -eq 'PASS') { 'Green' } else { 'Red' })
}

if ($finalStatus -eq 'PASS') { exit 0 }
exit 1
