[CmdletBinding()]
param([string]$DynomaxConfigPath,[switch]$CheckOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=if($DynomaxConfigPath){Split-Path -Parent $DynomaxConfigPath}else{$current=[System.IO.Path]::GetFullPath($PSScriptRoot);while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent};$current}
if(-not $root -or -not(Test-Path(Join-Path $root 'dynomax.json'))){throw 'Dynomax root not found.'}
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Process.ps1')
if(-not $DynomaxConfigPath){$DynomaxConfigPath=Join-Path $root 'dynomax.json'}
$config=Read-DynomaxJson -Path $DynomaxConfigPath
$path=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.prerequisiteConfig
$definition=Read-DynomaxJson -Path $path
$allowInstall=[bool]$definition.allowInstallMissingComponents -and -not $CheckOnly
$python=Resolve-DynomaxCommand -Candidates @($definition.pythonCommandCandidates)
$failures=New-Object System.Collections.Generic.List[string]
$logging=Get-DynomaxPropertyValue -Object $definition -Name 'logging' -DefaultValue ([pscustomobject]@{})
$showCommands=[bool](Get-DynomaxPropertyValue -Object $logging -Name 'showCommands' -DefaultValue $true)
$streamOutput=[bool](Get-DynomaxPropertyValue -Object $logging -Name 'streamProcessOutput' -DefaultValue $true)
$showSkipped=[bool](Get-DynomaxPropertyValue -Object $logging -Name 'showSkippedPostInstall' -DefaultValue $true)
$heartbeatSeconds=[int](Get-DynomaxPropertyValue -Object $logging -Name 'heartbeatSeconds' -DefaultValue 15)
$defaultProbeTimeout=[int](Get-DynomaxPropertyValue -Object $definition -Name 'defaultProbeTimeoutSeconds' -DefaultValue 60)
$defaultInstallTimeout=[int](Get-DynomaxPropertyValue -Object $definition -Name 'defaultInstallTimeoutSeconds' -DefaultValue 1200)

function Invoke-PrerequisiteProcess {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Purpose,
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments=@(),
        [int]$TimeoutSeconds=60
    )
    Write-DynomaxLog -Message ("{0}: {1}" -f $Id,$Purpose) -Level Information
    return Invoke-DynomaxProcess -FilePath $FilePath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds -StreamOutput:$streamOutput -ShowCommand:$showCommands -HeartbeatSeconds $heartbeatSeconds -DisplayName $Id
}

function Test-PostInstallCondition {
    param($Post,[bool]$InstalledThisRun)
    $runWhen=[string](Get-DynomaxPropertyValue -Object $Post -Name 'runWhen' -DefaultValue 'InstalledThisRun')
    switch($runWhen){
        'Always'{return $true}
        'InstalledThisRun'{return $InstalledThisRun}
        'Never'{return $false}
        default{throw "Unsupported postInstall runWhen value '$runWhen'."}
    }
}

foreach($requirement in @($definition.requirements)){
    $ok=$false
    $installedThisRun=$false
    $requirementStopwatch=[System.Diagnostics.Stopwatch]::StartNew()
    Write-DynomaxLog -Message ("{0}: checking prerequisite kind {1}." -f $requirement.id,$requirement.kind) -Level Information
    try{
        $probeTimeout=[int](Get-DynomaxPropertyValue -Object $requirement -Name 'probeTimeoutSeconds' -DefaultValue $defaultProbeTimeout)
        $installTimeout=[int](Get-DynomaxPropertyValue -Object $requirement -Name 'installTimeoutSeconds' -DefaultValue $defaultInstallTimeout)
        switch([string]$requirement.kind){
            'Windows'{$ok=Test-DynomaxWindows}
            'PowerShell'{$minimum=[version]$requirement.minimumVersion;$ok=($PSVersionTable.PSVersion -ge $minimum)}
            'Command'{
                $command=Resolve-DynomaxCommand -Candidates @($requirement.candidates)
                if($command){$probe=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose 'checking installed command version.' -FilePath $command -Arguments @($requirement.versionArguments) -TimeoutSeconds $probeTimeout;$ok=($probe.ExitCode -eq 0)}
            }
            'PythonPackage'{
                if(-not $python){$ok=$false;break}
                $probe=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose ("checking Python import '{0}'." -f $requirement.importName) -FilePath $python -Arguments @('-B','-c',"import importlib; importlib.import_module('$($requirement.importName)')") -TimeoutSeconds $probeTimeout
                $ok=($probe.ExitCode -eq 0)
                if(-not $ok -and $allowInstall -and [bool]$requirement.install){
                    Write-DynomaxLog -Message ("{0}: package missing; installing {1}." -f $requirement.id,$requirement.package) -Level Warning
                    $install=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose ("installing Python package '{0}'." -f $requirement.package) -FilePath $python -Arguments @('-B','-m','pip','install','--upgrade',[string]$requirement.package) -TimeoutSeconds $installTimeout
                    if($install.ExitCode -ne 0){throw $install.StandardError}
                    $installedThisRun=$true
                    $verify=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose 'verifying package import after installation.' -FilePath $python -Arguments @('-B','-c',"import importlib; importlib.import_module('$($requirement.importName)')") -TimeoutSeconds $probeTimeout
                    $ok=($verify.ExitCode -eq 0)
                }
                $postInstall=Get-DynomaxPropertyValue -Object $requirement -Name 'postInstall' -DefaultValue @()
                if($ok -and $allowInstall -and @($postInstall).Count -gt 0){
                    foreach($post in @($postInstall)){
                        if(-not(Test-PostInstallCondition -Post $post -InstalledThisRun $installedThisRun)){
                            if($showSkipped){Write-DynomaxLog -Message ("{0}: skipped post-install action because runWhen={1} and installedThisRun={2}." -f $requirement.id,(Get-DynomaxPropertyValue -Object $post -Name 'runWhen' -DefaultValue 'InstalledThisRun'),$installedThisRun) -Level Information}
                            continue
                        }
                        $postTimeout=[int](Get-DynomaxPropertyValue -Object $post -Name 'timeoutSeconds' -DefaultValue $installTimeout)
                        $pythonModule=Get-DynomaxPropertyValue -Object $post -Name 'pythonModule' -DefaultValue $null
                        if($pythonModule){
                            $postResult=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose ("running post-install Python module '{0}'." -f $pythonModule) -FilePath $python -Arguments (@('-B','-m',[string]$pythonModule)+@($post.arguments)) -TimeoutSeconds $postTimeout
                        } else {
                            $cmd=Resolve-DynomaxCommand -Candidates @($post.commandCandidates)
                            if(-not $cmd){throw "Post-install command was not found for $($requirement.id)."}
                            $postResult=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose 'running configured post-install command.' -FilePath $cmd -Arguments @($post.arguments) -TimeoutSeconds $postTimeout
                        }
                        if($postResult.ExitCode -ne 0){throw $postResult.StandardError}
                    }
                }
            }
            'NodePackage'{
                $npm=Resolve-DynomaxCommand -Candidates @('npm.cmd','npm.exe','npm')
                if($npm){
                    $args=if([bool]$requirement.global){@('list','-g','--depth=0',[string]$requirement.package)}else{@('list','--depth=0',[string]$requirement.package)}
                    $probe=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose ("checking Node package '{0}'." -f $requirement.package) -FilePath $npm -Arguments $args -TimeoutSeconds $probeTimeout
                    $ok=($probe.ExitCode -eq 0)
                    if(-not $ok -and $allowInstall -and [bool]$requirement.install){
                        Write-DynomaxLog -Message ("{0}: package missing; installing {1}." -f $requirement.id,$requirement.package) -Level Warning
                        $installArgs=if([bool]$requirement.global){@('install','-g',[string]$requirement.package)}else{@('install',[string]$requirement.package)}
                        $install=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose ("installing Node package '{0}'." -f $requirement.package) -FilePath $npm -Arguments $installArgs -TimeoutSeconds $installTimeout
                        if($install.ExitCode -ne 0){throw $install.StandardError}
                        $installedThisRun=$true
                        $verify=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose 'verifying Node package after installation.' -FilePath $npm -Arguments $args -TimeoutSeconds $probeTimeout
                        $ok=($verify.ExitCode -eq 0)
                    }
                    $postInstall=Get-DynomaxPropertyValue -Object $requirement -Name 'postInstall' -DefaultValue @()
                    if($ok -and $allowInstall -and @($postInstall).Count -gt 0){
                        foreach($post in @($postInstall)){
                            if(-not(Test-PostInstallCondition -Post $post -InstalledThisRun $installedThisRun)){
                                if($showSkipped){Write-DynomaxLog -Message ("{0}: skipped post-install action because runWhen={1} and installedThisRun={2}." -f $requirement.id,(Get-DynomaxPropertyValue -Object $post -Name 'runWhen' -DefaultValue 'InstalledThisRun'),$installedThisRun) -Level Information}
                                continue
                            }
                            $cmd=Resolve-DynomaxCommand -Candidates @($post.commandCandidates)
                            if(-not $cmd){throw "Post-install command was not found for $($requirement.id)."}
                            $postTimeout=[int](Get-DynomaxPropertyValue -Object $post -Name 'timeoutSeconds' -DefaultValue $installTimeout)
                            $postResult=Invoke-PrerequisiteProcess -Id $requirement.id -Purpose 'running configured post-install command.' -FilePath $cmd -Arguments @($post.arguments) -TimeoutSeconds $postTimeout
                            if($postResult.ExitCode -ne 0){throw $postResult.StandardError}
                        }
                    }
                }
            }
            'PowerShellModule'{
                $ok=[bool](Get-Module -ListAvailable -Name ([string]$requirement.module))
                if(-not $ok -and $allowInstall -and [bool]$requirement.install){
                    Write-DynomaxLog -Message ("{0}: installing PowerShell module '{1}'." -f $requirement.id,$requirement.module) -Level Warning
                    Install-Module -Name ([string]$requirement.module) -Scope CurrentUser -Force -AllowClobber
                    $installedThisRun=$true
                    $ok=[bool](Get-Module -ListAvailable -Name ([string]$requirement.module))
                }
            }
            default{throw "Unsupported prerequisite kind '$($requirement.kind)'."}
        }
    }catch{Write-DynomaxLog -Message "$($requirement.id): $($_.Exception.Message)" -Level Error;$ok=$false}
    $requirementStopwatch.Stop()
    if($ok){Write-DynomaxLog -Message ("{0}: PASS in {1}." -f $requirement.id,(Format-DynomaxElapsed $requirementStopwatch.Elapsed)) -Level Success}else{Write-DynomaxLog -Message ("{0}: MISSING OR INVALID after {1}." -f $requirement.id,(Format-DynomaxElapsed $requirementStopwatch.Elapsed)) -Level Warning;if([bool]$requirement.required){$failures.Add([string]$requirement.id)}}
}
if($failures.Count -gt 0){throw ("Required prerequisites failed: "+($failures -join ', '))}
