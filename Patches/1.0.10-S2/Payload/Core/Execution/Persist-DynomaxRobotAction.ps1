[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][int]$StepOrder,
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
$config=Read-DynomaxJson -Path (Join-Path $DynomaxRoot 'dynomax.json')
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
$message=''
if($MessageBase64){$message=[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($MessageBase64))}
$context=Read-DynomaxJson -Path $ContextPath
$classificationProperty="currentClassification.$ActionKey"
$explicit=$null
if($context.values.PSObject.Properties.Name -contains $classificationProperty){$explicit=[string]$context.values.$classificationProperty}
$status=switch($RobotStatus.ToUpperInvariant()){'PASS'{'PASS'} 'SKIP'{'SKIPPED'} default {if($explicit){$explicit}else{'FAIL'}}}
$cleanup=[System.Convert]::ToBoolean($IsCleanup)
if($cleanup -and $status -notin @('PASS','SKIPPED')){$status='CLEANUP_FAILED'}

$secretLookup=@{}
foreach($secretKey in @(Get-DynomaxPropertyValue -Object $context -Name 'secretKeys' -DefaultValue @())){
    if(-not [string]::IsNullOrWhiteSpace([string]$secretKey)){$secretLookup[[string]$secretKey]=$true}
}
$sanitizedValues=[ordered]@{}
foreach($property in @($context.values.PSObject.Properties)){
    if(-not $secretLookup.ContainsKey([string]$property.Name)){
        $sanitizedValues[[string]$property.Name]=$property.Value
    }
}
$outputJson=$sanitizedValues|ConvertTo-Json -Depth 50 -Compress
Add-DynomaxActionRun -SqlConfig $sqlConfig -RunId $RunId -StepOrder $StepOrder -ActionKey $ActionKey -ActionVersionId $ActionVersionId -Status $status -Message $message -OutputJson $outputJson -IsCleanup:$cleanup
if($status -notin @('PASS','SKIPPED') -and -not $cleanup){
    if(-not ($context.values.PSObject.Properties.Name -contains 'workflowBlocked')){Add-Member -InputObject $context.values -NotePropertyName 'workflowBlocked' -NotePropertyValue $true}else{$context.values.workflowBlocked=$true}
    Write-DynomaxJson -Value $context -Path $ContextPath
}
Set-DynomaxContextValuesInSql -SqlConfig $sqlConfig -RunId $RunId -Context $context
