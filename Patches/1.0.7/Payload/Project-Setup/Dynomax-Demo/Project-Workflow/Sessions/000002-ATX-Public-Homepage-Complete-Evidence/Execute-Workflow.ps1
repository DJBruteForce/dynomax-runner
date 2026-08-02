[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
while($root -and -not(Test-Path(Join-Path $root 'dynomax.json'))){$parent=Split-Path -Parent $root;if($parent -eq $root){break};$root=$parent}
if(-not $root){throw 'Dynomax root was not found.'}
& (Join-Path $root 'Core\Invoke-DynomaxWorkflow.ps1') -WorkflowDirectory $PSScriptRoot
exit $LASTEXITCODE
