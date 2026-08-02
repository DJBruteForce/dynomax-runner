[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][int]$StepOrder,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')

$context = Read-DynomaxJson -Path $ContextPath
$values = $context.values
$runDirectory = Split-Path -Parent $ContextPath
$exportDirectory = Ensure-DynomaxDirectory -Path (Join-Path $runDirectory 'project-export')

$cleanupDirectory = Ensure-DynomaxDirectory -Path (Join-Path $runDirectory 'cleanup-demo')
$cleanupMarker = Join-Path $cleanupDirectory 'marker.txt'
[System.IO.File]::WriteAllText($cleanupMarker, "Dynomax cleanup marker for run $RunId", (New-Object System.Text.UTF8Encoding($false)))
if (-not ($context.values.PSObject.Properties.Name -contains 'cleanupMarkerRelativePath')) {
    Add-Member -InputObject $context.values -NotePropertyName 'cleanupMarkerRelativePath' -NotePropertyValue 'cleanup-demo\\marker.txt'
}
else { $context.values.cleanupMarkerRelativePath = 'cleanup-demo\\marker.txt' }
Write-DynomaxJson -Value $context -Path $ContextPath


$findings = [ordered]@{
    schemaVersion = 1
    runId = [string]$RunId
    observedAtUtc = [DateTime]::UtcNow.ToString('o')
    project = 'Dynomax Demo'
    configuredTarget = 'https://atxsolutions.co.za/'
    websiteTitle = [string](Get-DynomaxPropertyValue -Object $values -Name 'websiteTitle' -DefaultValue '')
    websiteUrl = [string](Get-DynomaxPropertyValue -Object $values -Name 'websiteUrl' -DefaultValue '')
    pageLanguage = [string](Get-DynomaxPropertyValue -Object $values -Name 'pageLanguage' -DefaultValue '')
    metaDescription = [string](Get-DynomaxPropertyValue -Object $values -Name 'metaDescription' -DefaultValue '')
    firstH1 = [string](Get-DynomaxPropertyValue -Object $values -Name 'firstH1' -DefaultValue '')
    bodyTextLength = [int](Get-DynomaxPropertyValue -Object $values -Name 'bodyTextLength' -DefaultValue 0)
    bodyTextPreview = [string](Get-DynomaxPropertyValue -Object $values -Name 'bodyTextPreview' -DefaultValue '')
    headings = [ordered]@{
        total = [int](Get-DynomaxPropertyValue -Object $values -Name 'headingCount' -DefaultValue 0)
        h1 = [int](Get-DynomaxPropertyValue -Object $values -Name 'h1Count' -DefaultValue 0)
        h2 = [int](Get-DynomaxPropertyValue -Object $values -Name 'h2Count' -DefaultValue 0)
        h3 = [int](Get-DynomaxPropertyValue -Object $values -Name 'h3Count' -DefaultValue 0)
    }
    elements = [ordered]@{
        links = [int](Get-DynomaxPropertyValue -Object $values -Name 'linkCount' -DefaultValue 0)
        buttons = [int](Get-DynomaxPropertyValue -Object $values -Name 'buttonCount' -DefaultValue 0)
        forms = [int](Get-DynomaxPropertyValue -Object $values -Name 'formCount' -DefaultValue 0)
        images = [int](Get-DynomaxPropertyValue -Object $values -Name 'imageCount' -DefaultValue 0)
        inputs = [int](Get-DynomaxPropertyValue -Object $values -Name 'inputCount' -DefaultValue 0)
    }
    screenshot = [string](Get-DynomaxPropertyValue -Object $values -Name 'screenshotFile' -DefaultValue '')
    sharedContextVerified = [bool](Get-DynomaxPropertyValue -Object $values -Name 'sharedContextVerified' -DefaultValue $false)
}

Write-DynomaxJson -Value $findings -Path (Join-Path $exportDirectory 'WebsiteFindings.json')

$lines = @(
    '# Dynomax Demo Website Findings',
    '',
    "- Run ID: $RunId",
    "- Observed at UTC: $($findings.observedAtUtc)",
    "- Configured target: $($findings.configuredTarget)",
    "- Final URL: $($findings.websiteUrl)",
    "- Page title: $($findings.websiteTitle)",
    "- Language: $($findings.pageLanguage)",
    "- First H1: $($findings.firstH1)",
    "- Meta description: $($findings.metaDescription)",
    "- Body text length: $($findings.bodyTextLength)",
    "- Headings: $($findings.headings.total) (H1 $($findings.headings.h1), H2 $($findings.headings.h2), H3 $($findings.headings.h3))",
    "- Links: $($findings.elements.links)",
    "- Buttons: $($findings.elements.buttons)",
    "- Forms: $($findings.elements.forms)",
    "- Images: $($findings.elements.images)",
    "- Inputs: $($findings.elements.inputs)",
    "- Screenshot: $($findings.screenshot)",
    "- Shared action context verified: $($findings.sharedContextVerified)",
    '',
    '## Visible body text preview',
    '',
    $findings.bodyTextPreview
)
[System.IO.File]::WriteAllLines((Join-Path $exportDirectory 'WebsiteFindings.md'), $lines, (New-Object System.Text.UTF8Encoding($false)))

$result = [ordered]@{
    status = 'PASS'
    message = 'Website findings report created.'
    findingsReportCreated = $true
    cleanupMarkerCreated = (Test-Path -LiteralPath $cleanupMarker)
    findings = $findings
}
Write-DynomaxJson -Value $result -Path $OutputPath
