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
    'requestedActionVersion=',
    'resolvedActionVersion='
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
    '$workflowVersionId=Import-DynomaxWorkflowDefinition',
    '-WorkflowVersionId $workflowVersionId',
    'exactActionVersionsPinned=',
    'schemaVersion=2',
    'sourceVerified='
)

$version = [System.IO.File]::ReadAllText((Join-Path $root 'VERSION.txt')).Trim()
if ($version -ne '1.0.9') { throw "Expected VERSION.txt 1.0.9, found '$version'." }
$config = [System.IO.File]::ReadAllText((Join-Path $root 'dynomax.json')) | ConvertFrom-Json
if ([string]$config.frameworkVersion -ne '1.0.9') { throw 'Expected dynomax.json frameworkVersion 1.0.9.' }

if ($AssertNoSqlFiles) {
    $sqlFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.sql' -ErrorAction SilentlyContinue)
    if ($sqlFiles.Count -gt 0) { throw 'The 1.0.9 exact-version patch payload must not contain SQL files.' }
}

Write-Host '[ExactVersionContract] PASS: exact workflow/action version markers, fail-closed source verification, result mapping and no-schema-change boundary are present.' -ForegroundColor Green
exit 0
