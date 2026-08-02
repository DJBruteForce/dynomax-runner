[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectFolder = Split-Path -Parent $PSScriptRoot
$current = $projectFolder
while ($current -and -not (Test-Path (Join-Path $current 'dynomax.json'))) {
    $parent = Split-Path -Parent $current
    if ($parent -eq $current) { break }
    $current = $parent
}
if (-not $current -or -not (Test-Path (Join-Path $current 'dynomax.json'))) { throw 'Dynomax root not found.' }
. (Join-Path $current 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $current 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $current 'Core\Catalogue\Dynomax.Catalogue.ps1')
$config = Read-DynomaxJson -Path (Join-Path $current 'dynomax.json')
$databaseConfig = Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $current -ConfiguredPath $config.paths.databaseConfig)
Import-DynomaxProjectFolder -ProjectFolder $projectFolder -SqlConfig $databaseConfig.sql
Write-Host 'Dynomax Demo project imported successfully.' -ForegroundColor Green
