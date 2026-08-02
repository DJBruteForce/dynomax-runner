[CmdletBinding()]
param([string]$DynomaxConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=if($DynomaxConfigPath){Split-Path -Parent $DynomaxConfigPath}else{$current=[System.IO.Path]::GetFullPath($PSScriptRoot);while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent};$current}
if(-not $root -or -not(Test-Path(Join-Path $root 'dynomax.json'))){throw 'Dynomax root not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
if(-not $DynomaxConfigPath){$DynomaxConfigPath=Join-Path $root 'dynomax.json'}
$main=Read-DynomaxJson -Path $DynomaxConfigPath
$configPath=Resolve-DynomaxPath -Root $root -ConfiguredPath $main.paths.databaseConfig
$config=Read-DynomaxJson -Path $configPath
$sql=$config.sql
if([string]$sql.database -notmatch '^[A-Za-z0-9_]+$'){throw 'Database name may contain only letters, digits and underscore.'}
$master=$null
try{
    $master=Open-DynomaxConnection -SqlConfig $sql -DatabaseOverride 'master'
    $exists=[int](Invoke-DynomaxSqlScalar -Connection $master -CommandText 'SELECT COUNT(*) FROM sys.databases WHERE name=@Name;' -Parameters @{'@Name'=[string]$sql.database})
    if($exists -eq 0){
        if(-not [bool]$config.createDatabaseWhenMissing){throw "Database '$($sql.database)' does not exist."}
        [void](Invoke-DynomaxSqlNonQuery -Connection $master -CommandText ("CREATE DATABASE [{0}];" -f ([string]$sql.database)))
        Write-DynomaxLog -Message "Created database '$($sql.database)'." -Level Success
    }
}finally{if($master){$master.Dispose()}}
$migrationFolder=Join-Path (Split-Path -Parent $configPath) ([string]$config.migrationFolder)
$bootstrap=Join-Path $migrationFolder '0000_Bootstrap.sql'
$connection=Open-DynomaxConnection -SqlConfig $sql
try{
    $bootstrapText=[System.IO.File]::ReadAllText($bootstrap)
    foreach($batch in Split-DynomaxSqlBatches -SqlText $bootstrapText){[void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText $batch -CommandTimeoutSeconds ([int]$sql.commandTimeoutSeconds))}
    $migrationFiles=Get-ChildItem -LiteralPath $migrationFolder -Filter '*.sql' -File|Where-Object{$_.Name -ne '0000_Bootstrap.sql'}|Sort-Object Name
    foreach($file in $migrationFiles){
        $id=[System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $hash=Get-DynomaxSha256 -Path $file.FullName
        $row=Invoke-DynomaxSqlRows -Connection $connection -CommandText 'SELECT Checksum,Succeeded FROM dmx.MigrationHistory WHERE MigrationId=@Id;' -Parameters @{'@Id'=$id}
        if($row.Rows.Count -gt 0){if([string]$row.Rows[0].Checksum -ne $hash){throw "Migration checksum mismatch: $id"};if([bool]$row.Rows[0].Succeeded){continue}}
        $watch=[System.Diagnostics.Stopwatch]::StartNew();$transaction=$connection.BeginTransaction()
        try{
            $text=[System.IO.File]::ReadAllText($file.FullName)
            foreach($batch in Split-DynomaxSqlBatches -SqlText $text){[void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText $batch -CommandTimeoutSeconds ([int]$sql.commandTimeoutSeconds))}
            [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText @'
MERGE dmx.MigrationHistory AS target USING(SELECT @Id AS MigrationId) AS source ON target.MigrationId=source.MigrationId
WHEN MATCHED THEN UPDATE SET Checksum=@Checksum,AppliedAtUtc=SYSUTCDATETIME(),DurationMilliseconds=@Duration,Succeeded=1,ErrorMessage=NULL
WHEN NOT MATCHED THEN INSERT(MigrationId,Checksum,AppliedAtUtc,DurationMilliseconds,Succeeded) VALUES(@Id,@Checksum,SYSUTCDATETIME(),@Duration,1);
'@ -Parameters @{'@Id'=$id;'@Checksum'=$hash;'@Duration'=[int]$watch.ElapsedMilliseconds})
            $transaction.Commit();Write-DynomaxLog -Message "Applied migration $id." -Level Success
        }catch{
            $errorText=$_.Exception.ToString()
            try{$transaction.Rollback()}catch{}
            try{[void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
MERGE dmx.MigrationHistory AS target USING(SELECT @Id AS MigrationId) AS source ON target.MigrationId=source.MigrationId
WHEN MATCHED THEN UPDATE SET Checksum=@Checksum,AppliedAtUtc=SYSUTCDATETIME(),DurationMilliseconds=@Duration,Succeeded=0,ErrorMessage=@Error
WHEN NOT MATCHED THEN INSERT(MigrationId,Checksum,AppliedAtUtc,DurationMilliseconds,Succeeded,ErrorMessage) VALUES(@Id,@Checksum,SYSUTCDATETIME(),@Duration,0,@Error);
'@ -Parameters @{'@Id'=$id;'@Checksum'=$hash;'@Duration'=[int]$watch.ElapsedMilliseconds;'@Error'=$errorText})}catch{}
            throw
        }finally{$watch.Stop()}
    }
}finally{$connection.Dispose()}
if([bool]$config.validateAfterMigration){& (Join-Path $root 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1') -DynomaxConfigPath $DynomaxConfigPath -DatabaseOnly}
