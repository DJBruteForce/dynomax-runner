[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SourceRoot,
    [switch]$AssertNoSqlFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($SourceRoot)

function Assert-DynomaxFileContains {
    param([Parameter(Mandatory = $true)][string]$RelativePath,[Parameter(Mandatory = $true)][string[]]$RequiredText)
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $RelativePath" }
    $text = [System.IO.File]::ReadAllText($path)
    foreach ($required in $RequiredText) {
        if ($text.IndexOf($required, [System.StringComparison]::Ordinal) -lt 0) {
            throw "Contract marker '$required' is missing from '$RelativePath'."
        }
    }
}

Assert-DynomaxFileContains 'Core\Catalogue\Dynomax.Catalogue.ps1' @(
    'function Get-DynomaxActionVersionRecord',
    'av.VersionNumber=@VersionNumber',
    'function Get-DynomaxWorkflowVersionRecord'
)
Assert-DynomaxFileContains 'Core\Results\Dynomax.Results.ps1' @(
    '[Guid]$WorkflowVersionId = [Guid]::Empty',
    'wv.WorkflowVersionId=@WorkflowVersionId',
    '[Guid]$ActionVersionId = [Guid]::Empty',
    'av.ActionVersionId=@ActionVersionId',
    "Get-DynomaxPropertyValue -Object `$Context -Name 'secretKeys'",
    '''{"redacted":true}''',
    'IsSecret=@IsSecret',
    '$secretContextKeys=@{}',
    '$actionOutput.PSObject.Properties.Remove',
    'if([bool]$row.IsSecret){continue}'
)
Assert-DynomaxFileContains 'Core\Execution\Dynomax.Workflow.ps1' @(
    'Resolve-DynomaxActionExecutionSource',
    'function Assert-DynomaxActionExecutionSourceUnchanged',
    'changed after preflight and execution was stopped before the action started',
    '$fingerprint=Assert-DynomaxActionExecutionSourceUnchanged',
    "-Classification 'STALE'",
    'A version-pinned workflow must specify actionVersion on every normal and cleanup step.',
    'DYNOMAX_ACTION_VERSION_ID',
    'one contiguous Robot block per normal or cleanup section'
)
Assert-DynomaxFileContains 'Core\Execution\Persist-DynomaxRobotAction.ps1' @(
    '[Parameter(Mandatory)][Guid]$ActionVersionId',
    '-ActionVersionId $ActionVersionId',
    '$secretLookup=@{}',
    '$sanitizedValues=[ordered]@{}',
    '-OutputJson $outputJson'
)
Assert-DynomaxFileContains 'Core\Robot\Dynomax.resource' @(
    '-ActionVersionId',
    '${DYNOMAX_ACTION_VERSION_ID}'
)
Assert-DynomaxFileContains 'Core\Invoke-DynomaxWorkflow.ps1' @(
    '[string]$RuntimeProjectFolder',
    '[string]$ContextSeedPath',
    '[string]$RunContractPath',
    '[switch]$SuppressClipboard',
    '$catalogueAlreadyPublished=',
    'A database-published workflow must contain a valid workflowVersionId.',
    '$context=[ordered]@{schemaVersion=1;secretKeys=@();values=',
    '$context.secretKeys=',
    '-WorkflowVersionId $workflowVersionId',
    'resultZipPath=',
    'Set-DynomaxClipboardFile'
)


Assert-DynomaxFileContains 'Core\Robot\Dynomax.resource' @(
    'Fill Dynomax Secret',
    '[Arguments]    ${selector}    ${context_key}',
    '${previous_log_level}=    Set Log Level    NONE',
    "Get Dynomax Context",
    "secretKeys",
    'Fill Secret    ${selector}    $secret_value',
    'FINALLY',
    'Set Log Level    ${previous_log_level}'
)
$robotResource = [System.IO.File]::ReadAllText((Join-Path $root 'Core\Robot\Dynomax.resource'))
if ($robotResource.IndexOf('Fill Secret    ${selector}    ${secret_value}', [System.StringComparison]::Ordinal) -ge 0) {
    throw 'The Browser Fill Secret call must use Robot protected-variable syntax and may not pass ${secret_value}.'
}
if ($robotResource.IndexOf('enable_playwright_debug', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
    throw 'Playwright debug logging must not be enabled by the secret bridge payload.'
}

$version = [System.IO.File]::ReadAllText((Join-Path $root 'VERSION.txt')).Trim()
if ($version -ne '1.0.10') { throw "Expected VERSION.txt 1.0.10, found '$version'." }
$config = [System.IO.File]::ReadAllText((Join-Path $root 'dynomax.json')) | ConvertFrom-Json
if ([string]$config.frameworkVersion -ne '1.0.10') { throw 'Expected dynomax.json frameworkVersion 1.0.10.' }

if ($AssertNoSqlFiles) {
    $sqlFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.sql' -ErrorAction SilentlyContinue)
    if ($sqlFiles.Count -gt 0) { throw 'The 1.0.10 Core bridge payload must not contain SQL files.' }
}

Write-Host '[SecretBridgeContract] PASS: protected Browser secret filling and action-output secret redaction are present; Playwright debug logging is not enabled.' -ForegroundColor Green
exit 0
