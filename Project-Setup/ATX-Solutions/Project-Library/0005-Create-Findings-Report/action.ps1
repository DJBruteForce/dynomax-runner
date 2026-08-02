[CmdletBinding()]
param(
    [string]$ContextPath = $env:DYNOMAX_CONTEXT_PATH,
    [string]$RunDirectory = $env:DYNOMAX_RUN_DIRECTORY,
    [string]$ProjectRoot = $env:DYNOMAX_PROJECT_ROOT
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ContextPath)) { throw 'DYNOMAX_CONTEXT_PATH was not supplied to the reporting action.' }
if ([string]::IsNullOrWhiteSpace($RunDirectory)) { $RunDirectory = Split-Path -Parent $ContextPath }
$context = Get-Content -LiteralPath $ContextPath -Raw | ConvertFrom-Json
if (-not $context.sharedContextVerified) { throw 'Shared context verification did not pass.' }
$exportRoot = Join-Path $RunDirectory 'project-export'
if (-not (Test-Path -LiteralPath $exportRoot)) { New-Item -ItemType Directory -Path $exportRoot -Force | Out-Null }
$jsonPath = Join-Path $exportRoot 'website-findings.json'
$markdownPath = Join-Path $exportRoot 'website-findings.md'
$findings = [ordered]@{
    projectKey = 'atx-solutions'
    environment = 'production'
    observedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    websiteReachable = [bool]$context.websiteReachable
    finalUrl = [string]$context.websiteUrl
    navigationResult = [string]$context.navigationResult
    pageTitle = [string]$context.websiteTitle
    firstVisibleH1 = [string]$context.homepageInspection.firstVisibleH1
    pageLanguage = [string]$context.homepageInspection.pageLanguage
    counts = $context.homepageInspection.counts
    consoleObservation = $context.homepageInspection.consoleObservation
    resourceObservation = $context.homepageInspection.resourceObservation
    screenshot = [string]$context.homepageScreenshot
    sharedContextVerified = [bool]$context.sharedContextVerified
    boundaries = [ordered]@{
        authenticated = $false
        credentialsUsed = $false
        websiteDataModified = $false
        targetDatabaseQueried = $false
    }
}
$findings | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$lines = @(
    '# ATX Solutions Public Homepage Findings',
    '',
    ('- Observed at UTC: {0}' -f $findings.observedAtUtc),
    ('- Reachable: {0}' -f $findings.websiteReachable),
    ('- Final URL: {0}' -f $findings.finalUrl),
    ('- Navigation result: {0}' -f $findings.navigationResult),
    ('- Page title: {0}' -f $findings.pageTitle),
    ('- First visible H1: {0}' -f $findings.firstVisibleH1),
    ('- Page language: {0}' -f $findings.pageLanguage),
    '',
    '## Observable element counts',
    '',
    ('- Headings: {0}' -f $findings.counts.headings),
    ('- Links: {0}' -f $findings.counts.links),
    ('- Buttons: {0}' -f $findings.counts.buttons),
    ('- Forms: {0}' -f $findings.counts.forms),
    ('- Images: {0}' -f $findings.counts.images),
    ('- Inputs: {0}' -f $findings.counts.inputs),
    '',
    '## Safety boundary',
    '',
    '- No login or credentials were used.',
    '- No ATX website data was changed.',
    '- No ATX application database was queried.',
    '- Only the public homepage was observed.'
)
[System.IO.File]::WriteAllLines($markdownPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
$context | Add-Member -NotePropertyName findingsJson -NotePropertyValue $jsonPath -Force
$context | Add-Member -NotePropertyName findingsMarkdown -NotePropertyValue $markdownPath -Force
$context | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ContextPath -Encoding UTF8
Write-Output ([pscustomobject]@{ findingsJson=$jsonPath; findingsMarkdown=$markdownPath })
