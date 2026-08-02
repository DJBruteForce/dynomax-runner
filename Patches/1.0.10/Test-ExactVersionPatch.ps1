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
    'IsSecret=@IsSecret'
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
    '-ActionVersionId $ActionVersionId'
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

$version = [System.IO.File]::ReadAllText((Join-Path $root 'VERSION.txt')).Trim()
if ($version -ne '1.0.10') { throw "Expected VERSION.txt 1.0.10, found '$version'." }
$config = [System.IO.File]::ReadAllText((Join-Path $root 'dynomax.json')) | ConvertFrom-Json
if ([string]$config.frameworkVersion -ne '1.0.10') { throw 'Expected dynomax.json frameworkVersion 1.0.10.' }

if ($AssertNoSqlFiles) {
    $sqlFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.sql' -ErrorAction SilentlyContinue)
    if ($sqlFiles.Count -gt 0) { throw 'The 1.0.10 Core bridge payload must not contain SQL files.' }
}

Write-Host '[DatabaseRuntimeBridgeContract] PASS: exact-version execution, published-catalogue mode, disposable runtime paths, run contract and secret-context redaction markers are present.' -ForegroundColor Green
exit 0
