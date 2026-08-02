[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$DynomaxRoot,
    [Parameter(Mandatory=$true)][Guid]$RunId,
    [Parameter(Mandatory=$true)][int]$StepOrder,
    [Parameter(Mandatory=$true)][string]$ContextPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')

$context = Read-DynomaxJson -Path $ContextPath
$values = $context.values
$runDirectory = Split-Path -Parent $ContextPath
$exportDirectory = Ensure-DynomaxDirectory -Path (Join-Path $runDirectory 'project-export')
$resourceObservationJson = [string](Get-DynomaxPropertyValue -Object $values -Name 'resourceObservationJson' -DefaultValue '{"available":false}')
try { $resourceObservation = $resourceObservationJson | ConvertFrom-Json }
catch { $resourceObservation = [pscustomobject]@{ available=$false; note='Resource observation JSON could not be parsed.' } }

$findings = [ordered]@{
    schemaVersion = 1
    runId = [string]$RunId
    projectKey = 'atx-solutions'
    environment = 'production'
    observedAtUtc = [DateTime]::UtcNow.ToString('o')
    websiteReachable = [bool](Get-DynomaxPropertyValue -Object $values -Name 'websiteReachable' -DefaultValue $false)
    finalUrl = [string](Get-DynomaxPropertyValue -Object $values -Name 'websiteUrl' -DefaultValue '')
    navigationResult = [string](Get-DynomaxPropertyValue -Object $values -Name 'navigationResult' -DefaultValue '')
    pageTitle = [string](Get-DynomaxPropertyValue -Object $values -Name 'websiteTitle' -DefaultValue '')
    firstVisibleH1 = [string](Get-DynomaxPropertyValue -Object $values -Name 'firstVisibleH1' -DefaultValue '')
    pageLanguage = [string](Get-DynomaxPropertyValue -Object $values -Name 'pageLanguage' -DefaultValue '')
    counts = [ordered]@{
        visibleH1 = [int](Get-DynomaxPropertyValue -Object $values -Name 'visibleH1Count' -DefaultValue 0)
        headings = [int](Get-DynomaxPropertyValue -Object $values -Name 'headingCount' -DefaultValue 0)
        links = [int](Get-DynomaxPropertyValue -Object $values -Name 'linkCount' -DefaultValue 0)
        buttons = [int](Get-DynomaxPropertyValue -Object $values -Name 'buttonCount' -DefaultValue 0)
        forms = [int](Get-DynomaxPropertyValue -Object $values -Name 'formCount' -DefaultValue 0)
        images = [int](Get-DynomaxPropertyValue -Object $values -Name 'imageCount' -DefaultValue 0)
        inputs = [int](Get-DynomaxPropertyValue -Object $values -Name 'inputCount' -DefaultValue 0)
    }
    consoleObservation = [ordered]@{
        status = [string](Get-DynomaxPropertyValue -Object $values -Name 'consoleLogStatus' -DefaultValue 'UNAVAILABLE')
        log = [string](Get-DynomaxPropertyValue -Object $values -Name 'consoleLogText' -DefaultValue '')
    }
    resourceObservation = $resourceObservation
    screenshot = [string](Get-DynomaxPropertyValue -Object $values -Name 'screenshotFile' -DefaultValue '')
    sharedContextVerified = [bool](Get-DynomaxPropertyValue -Object $values -Name 'sharedContextVerified' -DefaultValue $false)
    boundaries = [ordered]@{
        authenticated = $false
        credentialsUsed = $false
        websiteDataModified = $false
        targetDatabaseQueried = $false
    }
}

$jsonPath = Join-Path $exportDirectory 'WebsiteFindings.json'
$markdownPath = Join-Path $exportDirectory 'WebsiteFindings.md'
Write-DynomaxJson -Value $findings -Path $jsonPath
$lines = @(
    '# ATX Solutions Public Homepage Findings',
    '',
    "- Run ID: $RunId",
    "- Observed at UTC: $($findings.observedAtUtc)",
    "- Reachable: $($findings.websiteReachable)",
    "- Final URL: $($findings.finalUrl)",
    "- Navigation result: $($findings.navigationResult)",
    "- Page title: $($findings.pageTitle)",
    "- First visible H1: $($findings.firstVisibleH1)",
    "- Page language: $($findings.pageLanguage)",
    '',
    '## Observable element counts',
    '',
    "- Visible H1 elements: $($findings.counts.visibleH1)",
    "- Headings: $($findings.counts.headings)",
    "- Links: $($findings.counts.links)",
    "- Buttons: $($findings.counts.buttons)",
    "- Forms: $($findings.counts.forms)",
    "- Images: $($findings.counts.images)",
    "- Inputs: $($findings.counts.inputs)",
    '',
    '## Browser console observation',
    '',
    "- Observation status: $($findings.consoleObservation.status)",
    '',
    $findings.consoleObservation.log,
    '',
    '## Failed-resource observation',
    '',
    "- Entries observed: $([int](Get-DynomaxPropertyValue -Object $values -Name 'resourceEntriesObserved' -DefaultValue 0))",
    "- Failed-resource candidates: $([int](Get-DynomaxPropertyValue -Object $values -Name 'failedResourceCandidateCount' -DefaultValue 0))",
    "- Observation note: $([string](Get-DynomaxPropertyValue -Object $resourceObservation -Name 'note' -DefaultValue ''))",
    '',
    '## Safety boundary',
    '',
    '- No login or credentials were used.',
    '- No ATX website data was changed.',
    '- No ATX application database was queried.',
    '- Only the public homepage was observed.'
)
[System.IO.File]::WriteAllLines($markdownPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
$result = [ordered]@{
    status = 'PASS'
    message = 'ATX public homepage findings report created.'
    findingsReportCreated = $true
    findingsJson = $jsonPath
    findingsMarkdown = $markdownPath
}
Write-DynomaxJson -Value $result -Path $OutputPath
