[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProjectKey,
    [Parameter(Mandatory)][string]$Name
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$current=$PSScriptRoot
while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent}
$root=$current
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
$config=Read-DynomaxJson -Path (Join-Path $root 'dynomax.json')
$databaseConfig=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig)
$sqlConfig=$databaseConfig.sql
$projectFolder=Get-DynomaxProjectFolder -DynomaxRoot $root -ProjectKey $ProjectKey
$connection=Open-DynomaxConnection -SqlConfig $sqlConfig
try{
    $transaction=$connection.BeginTransaction()
    try{
        $projectIdText=Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT CONVERT(nvarchar(36),ProjectId) FROM dmx.Project WHERE ProjectKey=@Key;' -Parameters @{'@Key'=$ProjectKey}
        if(-not $projectIdText){throw "Project '$ProjectKey' is not registered."}
        $projectId=[Guid]$projectIdText
        [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText 'IF NOT EXISTS(SELECT 1 FROM dmx.ProjectSequence WHERE ProjectId=@Id) INSERT INTO dmx.ProjectSequence(ProjectId,NextSessionNumber) VALUES(@Id,1);' -Parameters @{'@Id'=$projectId})
        $number=[long](Invoke-DynomaxSqlScalar -Connection $connection -Transaction $transaction -CommandText 'SELECT NextSessionNumber FROM dmx.ProjectSequence WITH(UPDLOCK,HOLDLOCK) WHERE ProjectId=@Id;' -Parameters @{'@Id'=$projectId})
        [void](Invoke-DynomaxSqlNonQuery -Connection $connection -Transaction $transaction -CommandText 'UPDATE dmx.ProjectSequence SET NextSessionNumber=NextSessionNumber+1 WHERE ProjectId=@Id;' -Parameters @{'@Id'=$projectId})
        $transaction.Commit()
    }catch{try{$transaction.Rollback()}catch{};throw}
}finally{$connection.Dispose()}
$safe=($Name -replace '[^A-Za-z0-9_.-]+','-').Trim('-')
$folderName=('{0:D6}-{1}' -f $number,$safe)
$destination=Join-Path $projectFolder ('Project-Workflow\Sessions\'+$folderName)
Copy-Item -LiteralPath (Join-Path $root 'Core\Templates\Workflow') -Destination $destination -Recurse
Write-Host "Created workflow session: $destination" -ForegroundColor Green
