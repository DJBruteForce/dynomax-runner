[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('BeforeAction','AfterAction','FailAction','AssertDiscoveryTarget')][string]$Mode,
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][string]$WorkflowPath,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$RunDirectory,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][string]$NodeId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.ControlFlow.ps1')
$config=Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')
$sqlConfigPath=Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$sqlConfig=$databaseConfig.sql
$workflow=Read-DynomaxJson -Path $WorkflowPath
if($Mode -eq 'BeforeAction'){
    $decision=Get-DynomaxControlFlowDecision -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $NodeId
    Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $RunId -RunDirectory $RunDirectory
    [Console]::Out.Write(([string]$decision.Disposition).ToUpperInvariant())
    exit 0
}
if($Mode -eq 'FailAction'){
    [void](Fail-DynomaxControlFlowAction -Workflow $workflow -RunDirectory $RunDirectory -NodeId $NodeId)
    Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $RunId -RunDirectory $RunDirectory
    [Console]::Out.Write('OK')
    exit 0
}
if($Mode -eq 'AssertDiscoveryTarget'){
    [void](Assert-DynomaxDiscoveryTargetReached -Workflow $workflow -RunDirectory $RunDirectory)
    [Console]::Out.Write('OK')
    exit 0
}
$state=Complete-DynomaxControlFlowAction -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -NodeId $NodeId
Sync-DynomaxControlFlowRunEvents -SqlConfig $sqlConfig -RunId $RunId -RunDirectory $RunDirectory
$terminalStatus=[string](Get-DynomaxPropertyValue -Object $state -Name 'terminalStatus' -DefaultValue '')
if($terminalStatus){
    [Console]::Out.Write(('TERMINAL_{0}' -f $terminalStatus.ToUpperInvariant()))
}
else{
    [Console]::Out.Write('CONTINUE')
}
