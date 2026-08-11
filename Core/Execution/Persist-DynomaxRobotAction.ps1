[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][int]$StepOrder,
    [Parameter(Mandatory)][string]$StepId,
    [Parameter(Mandatory)][string]$ActionKey,
    [Parameter(Mandatory)][Guid]$ActionVersionId,
    [Parameter(Mandatory)][string]$RobotStatus,
    [string]$MessageBase64,
    [Parameter(Mandatory)][string]$IsCleanup,
    [Parameter(Mandatory)][string]$ContextPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $DynomaxRoot 'Core\Results\Dynomax.Results.ps1')
. (Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Orchestration.ps1')
$config=Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
[void](Invoke-DynomaxActionResultPersistenceOperation -RunId $RunId -StepOrder $StepOrder -StepId $StepId -ActionKey $ActionKey -ActionVersionId $ActionVersionId -RobotStatus $RobotStatus -MessageBase64 $MessageBase64 -IsCleanup $IsCleanup -ContextPath $ContextPath -SqlConfig $sqlConfig)
