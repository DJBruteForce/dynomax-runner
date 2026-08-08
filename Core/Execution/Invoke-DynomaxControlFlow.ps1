[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('BeforeAction','AfterAction','FailAction','AssertDiscoveryTarget')][string]$Mode,
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][string]$WorkflowPath,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][string]$NodeId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ControlFlow.ps1')
$workflow=Read-DynomaxJson -Path $WorkflowPath
if($Mode -eq 'BeforeAction'){
    $decision=Get-DynomaxControlFlowDecision -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $NodeId
    [Console]::Out.Write(([string]$decision.Disposition).ToUpperInvariant())
    exit 0
}
if($Mode -eq 'FailAction'){
    [void](Fail-DynomaxControlFlowAction -Workflow $workflow -RunDirectory $RunDirectory -NodeId $NodeId)
    [Console]::Out.Write('OK')
    exit 0
}
if($Mode -eq 'AssertDiscoveryTarget'){
    [void](Assert-DynomaxDiscoveryTargetReached -Workflow $workflow -RunDirectory $RunDirectory)
    [Console]::Out.Write('OK')
    exit 0
}
[void](Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $NodeId)
[Console]::Out.Write('OK')
