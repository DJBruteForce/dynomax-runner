[CmdletBinding()]
param([string]$DynomaxConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=if($DynomaxConfigPath){Split-Path -Parent $DynomaxConfigPath}else{$current=[System.IO.Path]::GetFullPath($PSScriptRoot);while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent};$current}
if(-not $root -or -not(Test-Path(Join-Path $root 'dynomax.json'))){throw 'Dynomax root not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $root 'Core\Catalogue\Dynomax.Catalogue.ps1')
if(-not $DynomaxConfigPath){$DynomaxConfigPath=Join-Path $root 'dynomax.json'}
$config=Read-DynomaxJson -Path $DynomaxConfigPath
foreach($name in @('core','projects','tempRuns','exports')){Ensure-DynomaxDirectory -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.$name)|Out-Null}
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
$connection=Open-DynomaxConnection -SqlConfig $sqlConfig
try{
    [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText 'UPDATE dmx.FrameworkVersion SET IsCurrent=0;')
    [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
IF NOT EXISTS(SELECT 1 FROM dmx.FrameworkVersion WHERE VersionNumber=@Version)
INSERT INTO dmx.FrameworkVersion(FrameworkVersionId,VersionNumber,InstalledAtUtc,IsCurrent) VALUES(NEWID(),@Version,SYSUTCDATETIME(),1)
ELSE UPDATE dmx.FrameworkVersion SET IsCurrent=1,InstalledAtUtc=SYSUTCDATETIME() WHERE VersionNumber=@Version;
'@ -Parameters @{'@Version'=[string]$config.frameworkVersion})
    [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
MERGE dmx.Machine AS target USING(SELECT @Name AS MachineName) AS source ON target.MachineName=source.MachineName
WHEN MATCHED THEN UPDATE SET OsVersion=@Os,PowerShellVersion=@Ps,LastSeenAtUtc=SYSUTCDATETIME()
WHEN NOT MATCHED THEN INSERT(MachineId,MachineName,OsVersion,PowerShellVersion,LastSeenAtUtc) VALUES(NEWID(),@Name,@Os,@Ps,SYSUTCDATETIME());
'@ -Parameters @{'@Name'=$env:COMPUTERNAME;'@Os'=[Environment]::OSVersion.VersionString;'@Ps'=$PSVersionTable.PSVersion.ToString()})
}finally{$connection.Dispose()}
$projectsRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.projects
Get-ChildItem -LiteralPath $projectsRoot -Directory|Where-Object{Test-Path(Join-Path $_.FullName 'Project-And-Config\project.json')}|ForEach-Object{Import-DynomaxProjectFolder -ProjectFolder $_.FullName -SqlConfig $sqlConfig;Write-DynomaxLog -Message "Imported project folder $($_.Name)." -Level Success}
