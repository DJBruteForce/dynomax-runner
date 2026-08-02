[CmdletBinding()]
param([string]$DynomaxConfigPath,[switch]$DatabaseOnly,[switch]$SkipWebsiteValidation)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=if($DynomaxConfigPath){Split-Path -Parent $DynomaxConfigPath}else{$current=[System.IO.Path]::GetFullPath($PSScriptRoot);while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent};$current}
if(-not $root -or -not(Test-Path(Join-Path $root 'dynomax.json'))){throw 'Dynomax root not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
if(-not $DynomaxConfigPath){$DynomaxConfigPath=Join-Path $root 'dynomax.json'}
$config=Read-DynomaxJson -Path $DynomaxConfigPath
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
$contract=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.schemaContract)
$failures=New-Object System.Collections.Generic.List[string]
$connection=$null
if(-not $DatabaseOnly){if(Test-DynomaxWindows){Write-DynomaxLog -Message 'Windows platform: PASS' -Level Success}else{$failures.Add('Windows platform')}}
try{
    $connection=Open-DynomaxConnection -SqlConfig $sqlConfig
    Write-DynomaxLog -Message "SQL connection to $($sqlConfig.host)/$($sqlConfig.database): PASS" -Level Success
    if (Test-DynomaxBinarySqlParameter -Connection $connection) {
        Write-DynomaxLog -Message 'SQL binary parameter persistence: PASS' -Level Success
    }
    else {
        $failures.Add('SQL binary parameter persistence probe failed')
    }
    foreach($tableProperty in $contract.tables.PSObject.Properties){
        $table=[string]$tableProperty.Name
        $count=[int](Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name=@Schema AND t.name=@Table;' -Parameters @{'@Schema'=[string]$contract.schema;'@Table'=$table})
        if($count -ne 1){$failures.Add("Missing table $($contract.schema).$table");continue}
        foreach($column in @($tableProperty.Value)){
            $columnCount=[int](Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name=@Schema AND t.name=@Table AND c.name=@Column;' -Parameters @{'@Schema'=[string]$contract.schema;'@Table'=$table;'@Column'=[string]$column})
            if($columnCount -ne 1){$failures.Add("Missing column $($contract.schema).$table.$column")}
        }
    }
    foreach($foreignKey in @($contract.foreignKeys)){
        $fkCount=[int](Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT COUNT(*) FROM sys.foreign_keys WHERE name=@Name;' -Parameters @{'@Name'=[string]$foreignKey})
        if($fkCount -ne 1){$failures.Add("Missing foreign key $foreignKey")}
    }
    foreach($indexName in @($contract.indexes)){
        $indexCount=[int](Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT COUNT(*) FROM sys.indexes WHERE name=@Name;' -Parameters @{'@Name'=[string]$indexName})
        if($indexCount -ne 1){$failures.Add("Missing index $indexName")}
    }
} catch {$failures.Add($_.Exception.Message)} finally {if($connection){$connection.Dispose()}}
if($failures.Count -gt 0){$failures|ForEach-Object{Write-DynomaxLog -Message $_ -Level Error};throw ('Dynomax validation failed: '+($failures -join '; '))}
Write-DynomaxLog -Message 'Dynomax installation validation passed.' -Level Success
