[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DynomaxRoot,
    [Parameter(Mandatory)][Guid]$RunId,
    [Parameter(Mandatory)][int]$StepOrder,
    [Parameter(Mandatory)][string]$ContextPath,
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1')
$context=Read-DynomaxJson -Path $ContextPath
$runDirectory=Split-Path -Parent $ContextPath
$relative=[string](Get-DynomaxPropertyValue -Object $context.values -Name 'cleanupMarkerRelativePath' -DefaultValue 'cleanup-demo\marker.txt')
$marker=Join-Path $runDirectory $relative
$directory=Split-Path -Parent $marker
$existedBefore=Test-Path -LiteralPath $marker -PathType Leaf
if($existedBefore){Remove-Item -LiteralPath $marker -Force}
if(Test-Path -LiteralPath $directory -PathType Container){
    if(@(Get-ChildItem -LiteralPath $directory -Force).Count -eq 0){Remove-Item -LiteralPath $directory -Force}
}
$existsAfter=Test-Path -LiteralPath $marker
$result=[ordered]@{
    status=$(if($existedBefore -and -not $existsAfter){'PASS'}else{'CLEANUP_FAILED'})
    message=$(if(-not $existedBefore){'The expected cleanup marker did not exist.'}elseif($existsAfter){'The cleanup marker still exists.'}else{'The exact demo cleanup marker was removed and absence was verified.'})
    markerExistedBefore=$existedBefore
    markerExistsAfter=$existsAfter
    cleanupVerified=($existedBefore -and -not $existsAfter)
}
Write-DynomaxJson -Value $result -Path $OutputPath
if($result.status -eq 'PASS'){exit 0}else{exit 1}
