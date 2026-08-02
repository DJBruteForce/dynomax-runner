[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$patchDirectory=[System.IO.Path]::GetFullPath($PSScriptRoot)
$dynomaxRoot=Split-Path -Parent (Split-Path -Parent $patchDirectory)
$payloadRoot=Join-Path $patchDirectory 'Payload'
if(-not(Test-Path -LiteralPath (Join-Path $dynomaxRoot 'dynomax.json'))){throw "Dynomax root was not found at '$dynomaxRoot'."}
$currentVersion=[System.IO.File]::ReadAllText((Join-Path $dynomaxRoot 'VERSION.txt')).Trim()
if([version]$currentVersion -lt [version]'1.0.4'){throw "Dynomax 1.0.4 or later is required. Current version: $currentVersion"}
$backupRoot=Join-Path $patchDirectory ('Backup\'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))
[System.IO.Directory]::CreateDirectory($backupRoot)|Out-Null
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX 1.0.5: Apply complete export and cleanup closeout' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$prefix=$payloadRoot.TrimEnd('\')+'\'
foreach($file in Get-ChildItem -LiteralPath $payloadRoot -File -Recurse){
    $relative=$file.FullName.Substring($prefix.Length)
    $destination=Join-Path $dynomaxRoot $relative
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination))|Out-Null
    if(Test-Path -LiteralPath $destination){$backup=Join-Path $backupRoot $relative;[System.IO.Directory]::CreateDirectory((Split-Path -Parent $backup))|Out-Null;Copy-Item -LiteralPath $destination -Destination $backup -Force}
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
    Write-Host ("Updated {0}" -f $relative) -ForegroundColor Gray
}
$configPath=Join-Path $dynomaxRoot 'dynomax.json'
& (Join-Path $dynomaxRoot 'Config-And-Setup\03-Core\Initialize-DynomaxCore.ps1') -DynomaxConfigPath $configPath
& (Join-Path $dynomaxRoot 'Config-And-Setup\04-Validate-Installation\Test-DynomaxInstallation.ps1') -DynomaxConfigPath $configPath
& (Join-Path $dynomaxRoot 'Project-Setup\Dynomax-Demo\Project-And-Config\Configure-Project.ps1')
Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host 'DYNOMAX 1.0.5: Execute complete evidence closeout demo' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
$workflowScript=Join-Path $dynomaxRoot 'Project-Setup\Dynomax-Demo\Project-Workflow\Sessions\000002-ATX-Public-Homepage-Complete-Evidence\Execute-Workflow.ps1'
$started=[DateTime]::UtcNow
$psExe=if($PSVersionTable.PSEdition -eq 'Core'){Join-Path $PSHOME 'pwsh.exe'}else{Join-Path $PSHOME 'powershell.exe'}
& $psExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $workflowScript
$exitCode=$LASTEXITCODE
$pattern='Dynomax_dynomax-demo_demo.atx.public-homepage-complete-evidence_*.zip'
$result=Get-ChildItem -LiteralPath (Join-Path $dynomaxRoot 'Exports') -Filter $pattern -File|Where-Object{$_.LastWriteTimeUtc -ge $started.AddMinutes(-1)}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1
if(-not $result){throw 'The closeout demo did not create a result ZIP.'}
Write-Host ("Closeout result ZIP: {0}" -f $result.FullName) -ForegroundColor Cyan
Write-Host 'The ZIP has already been copied to the clipboard by Dynomax.' -ForegroundColor Green
Write-Host 'The browser and child processes are closed. This console will close automatically.' -ForegroundColor DarkGray
Start-Sleep -Seconds 2
exit $exitCode
