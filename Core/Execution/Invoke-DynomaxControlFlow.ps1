[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('BeforeAction','AfterAction','ReuseAction','FailAction','AssertDiscoveryTarget')][string]$Mode,
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
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Orchestration.ps1')
$config=Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')
$sqlConfigPath=Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$sqlConfig=$databaseConfig.sql
$workflow=Read-DynomaxJson -Path $WorkflowPath
$result=Invoke-DynomaxControlFlowOperation -Mode $Mode -Workflow $workflow -ContextPath $ContextPath -RunDirectory $RunDirectory -RunId $RunId -NodeId $NodeId -SqlConfig $sqlConfig
[Console]::Out.Write([string]$result)
