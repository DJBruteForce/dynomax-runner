Set-StrictMode -Version Latest

function Resolve-DynomaxActionFolder {
    param([Parameter(Mandatory)][string]$ProjectFolder,[Parameter(Mandatory)][string]$ActionKey,[string]$WorkflowDirectory)
    if($WorkflowDirectory){
        $payload=Join-Path $WorkflowDirectory 'Payload'
        if(Test-Path $payload){
            $payloadMatches=@(Get-ChildItem -LiteralPath $payload -Filter action.json -File -Recurse|Where-Object{try{(Read-DynomaxJson -Path $_.FullName).actionId -eq $ActionKey}catch{$false}})
            if($payloadMatches.Count -gt 1){throw "Workflow payload contains more than one action definition for '$ActionKey'."}
            if($payloadMatches.Count -eq 1){return $payloadMatches[0].Directory.FullName}
        }
    }
    $library=Join-Path $ProjectFolder 'Project-Library'
    $matches=@(Get-ChildItem -LiteralPath $library -Filter action.json -File -Recurse|Where-Object{try{(Read-DynomaxJson -Path $_.FullName).actionId -eq $ActionKey}catch{$false}})
    if($matches.Count -ne 1){throw "Expected one project-library action definition for '$ActionKey', found $($matches.Count)."}
    return $matches[0].Directory.FullName
}

function New-DynomaxRobotSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DynomaxRoot,[Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)]$ProjectConfig,[Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][object[]]$Steps,
        [Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$ContextPath,
        [Parameter(Mandatory)][string]$WorkflowDirectory,[Parameter(Mandatory)][string]$PowerShellPath
    )
    $resourcePaths=@()
    $actionDefinitions=@{}
    foreach($step in $Steps){
        $folder=Resolve-DynomaxActionFolder -ProjectFolder $ProjectFolder -ActionKey ([string]$step.actionId) -WorkflowDirectory $WorkflowDirectory
        $definition=Read-DynomaxJson -Path (Join-Path $folder 'action.json')
        if([string]$definition.engine -ne 'RobotBrowser'){throw "Action '$($step.actionId)' is not RobotBrowser."}
        if(-not $definition.keyword){throw "Robot action '$($step.actionId)' is missing keyword."}
        $entry=Join-Path $folder ([string]$definition.entryPoint)
        $resourcePaths += [System.IO.Path]::GetFullPath($entry).Replace('\','/')
        $actionDefinitions[[string]$step.actionId]=$definition
    }
    $environment=@($ProjectConfig.environments|Where-Object{$_.key -eq $Workflow.environment})
    if($environment.Count -ne 1){throw "Project environment '$($Workflow.environment)' was not found."}
    $baseUrl=[string]$environment[0].baseUrl
    $browser=[string](Get-DynomaxPropertyValue -Object $environment[0] -Name 'browser' -DefaultValue (Get-DynomaxPropertyValue -Object $ProjectConfig -Name 'browser' -DefaultValue 'chromium'))
    $headless=ConvertTo-DynomaxBooleanString (Get-DynomaxPropertyValue -Object $environment[0] -Name 'headless' -DefaultValue (Get-DynomaxPropertyValue -Object $ProjectConfig -Name 'headless' -DefaultValue $false))
    $viewportValue=Get-DynomaxPropertyValue -Object $environment[0] -Name 'viewport' -DefaultValue $null
    $viewport=if($viewportValue){$viewportValue|ConvertTo-Json -Compress}else{'{"width":1440,"height":900}'}
    $coreResource=[System.IO.Path]::GetFullPath((Join-Path $DynomaxRoot 'Core\Robot\Dynomax.resource')).Replace('\','/')
    $persistScript=[System.IO.Path]::GetFullPath((Join-Path $DynomaxRoot 'Core\Execution\Persist-DynomaxRobotAction.ps1')).Replace('\','/')
    $rootForward=[System.IO.Path]::GetFullPath($DynomaxRoot).Replace('\','/')
    $runForward=[System.IO.Path]::GetFullPath($RunDirectory).Replace('\','/')
    $contextForward=[System.IO.Path]::GetFullPath($ContextPath).Replace('\','/')
    $psForward=[System.IO.Path]::GetFullPath($PowerShellPath).Replace('\','/')
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add('*** Settings ***')
    $lines.Add("Resource    $coreResource")
    foreach($resource in ($resourcePaths|Select-Object -Unique)){$lines.Add("Resource    $resource")}
    $lines.Add('Suite Setup    Start Dynomax Browser')
    $lines.Add('Suite Teardown    Stop Dynomax Browser')
    $lines.Add('Test Teardown    Persist Dynomax Robot Action Result')
    $lines.Add('')
    $lines.Add('*** Variables ***')
    $lines.Add("`${DYNOMAX_ROOT}    $rootForward")
    $lines.Add("`${DYNOMAX_RUN_ID}    $RunId")
    $lines.Add("`${DYNOMAX_RUN_DIR}    $runForward")
    $lines.Add("`${DYNOMAX_CONTEXT_PATH}    $contextForward")
    $lines.Add("`${DYNOMAX_PERSIST_SCRIPT}    $persistScript")
    $lines.Add("`${DYNOMAX_POWERSHELL}    $psForward")
    $lines.Add("`${DYNOMAX_BASE_URL}    $baseUrl")
    $lines.Add("`${DYNOMAX_BROWSER}    $browser")
    $lines.Add("`${DYNOMAX_HEADLESS}    $headless")
    $lines.Add("`${DYNOMAX_VIEWPORT}    $viewport")
    $lines.Add('')
    $lines.Add('*** Test Cases ***')
    foreach($step in ($Steps|Sort-Object order)){
        $definition=$actionDefinitions[[string]$step.actionId]
        $cleanup=if([bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)){'True'}else{'False'}
        $name=('{0:D6} - {1}' -f [int]$step.order,[string]$step.actionId)
        $lines.Add($name)
        $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_ID}    $($step.actionId)")
        $lines.Add("    Set Test Variable    `${DYNOMAX_STEP_ORDER}    $($step.order)")
        $lines.Add("    Set Test Variable    `${DYNOMAX_IS_CLEANUP}    $cleanup")
        $lines.Add("    Execute Dynomax Action Keyword    $($definition.keyword)    $cleanup")
        $lines.Add('')
    }
    $suitePath=Join-Path $RunDirectory 'generated-workflow.robot'
    [System.IO.File]::WriteAllLines($suitePath,$lines,(New-Object System.Text.UTF8Encoding($false)))
    return $suitePath
}

function Invoke-DynomaxRobotBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DynomaxRoot,[Parameter(Mandatory)][string]$ProjectFolder,[Parameter(Mandatory)]$ProjectConfig,
        [Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][object[]]$Steps,[Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$WorkflowDirectory,
        [Parameter(Mandatory)][string]$PowerShellPath,[Parameter(Mandatory)][string]$PythonPath,[int]$TimeoutSeconds=0,
        [bool]$StreamOutput=$true,[bool]$ShowCommand=$false,[int]$HeartbeatSeconds=15
    )
    $suite=New-DynomaxRobotSuite -DynomaxRoot $DynomaxRoot -ProjectFolder $ProjectFolder -ProjectConfig $ProjectConfig -Workflow $Workflow -Steps $Steps -RunId $RunId -RunDirectory $RunDirectory -ContextPath $ContextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $PowerShellPath
    $resultDir=Ensure-DynomaxDirectory -Path (Join-Path $RunDirectory 'robot-result')
    $args=@('-B','-m','robot','--outputdir',$resultDir,'--output','output.xml','--log','log.html','--report','report.html',$suite)
    return Invoke-DynomaxProcess -FilePath $PythonPath -Arguments $args -WorkingDirectory $RunDirectory -TimeoutSeconds $TimeoutSeconds -ConsoleLogPath (Join-Path $RunDirectory 'robot-console.log') -Environment @{ 'PYTHONDONTWRITEBYTECODE'='1' } -StreamOutput:$StreamOutput -ShowCommand:$ShowCommand -HeartbeatSeconds $HeartbeatSeconds -DisplayName 'Robot workflow'
}


function Resolve-DynomaxExternalActionResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$ProcessResult,
        [string]$OutputPath,
        [bool]$IsCleanup = $false
    )
    $allowed=@('PASS','FAIL','TEST_INVALID','BLOCKED','ERROR','STALE','SKIPPED','CLEANUP_FAILED')
    $status=if($ProcessResult.ExitCode -eq 0){'PASS'}else{'ERROR'}
    $message=[string]$ProcessResult.StandardError
    $outputJson=$null
    if($OutputPath -and (Test-Path -LiteralPath $OutputPath -PathType Leaf)){
        $outputJson=[System.IO.File]::ReadAllText($OutputPath,[System.Text.Encoding]::UTF8)
        try{
            $output=$outputJson|ConvertFrom-Json
            $declared=Get-DynomaxPropertyValue -Object $output -Name 'status' -DefaultValue $null
            if($declared -and $allowed -contains ([string]$declared).ToUpperInvariant()){$status=([string]$declared).ToUpperInvariant()}
            $declaredMessage=Get-DynomaxPropertyValue -Object $output -Name 'message' -DefaultValue $null
            if($declaredMessage){$message=[string]$declaredMessage}
        }catch{
            if($ProcessResult.ExitCode -eq 0){$status='TEST_INVALID';$message="Action output is not valid JSON: $($_.Exception.Message)"}
        }
    }
    if($IsCleanup -and $status -notin @('PASS','SKIPPED')){$status='CLEANUP_FAILED'}
    return [pscustomobject]@{Status=$status;Message=$message;OutputJson=$outputJson}
}

function Invoke-DynomaxPowerShellAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DynomaxRoot,[Parameter(Mandatory)][string]$ProjectFolder,[Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)]$Step,[Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][string]$WorkflowDirectory,[Parameter(Mandatory)][string]$PowerShellPath,[Parameter(Mandatory)]$SqlConfig,
        [bool]$StreamOutput=$true,[bool]$ShowCommand=$false,[int]$HeartbeatSeconds=15
    )
    $folder=Resolve-DynomaxActionFolder -ProjectFolder $ProjectFolder -ActionKey ([string]$Step.actionId) -WorkflowDirectory $WorkflowDirectory
    $definition=Read-DynomaxJson -Path (Join-Path $folder 'action.json')
    $entry=Join-Path $folder ([string]$definition.entryPoint)
    $outputPath=Join-Path $RunDirectory ("action-{0}.json" -f $Step.order)
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-DynomaxRoot',$DynomaxRoot,'-RunId',[string]$RunId,'-StepOrder',[string]$Step.order,'-ContextPath',$ContextPath,'-OutputPath',$outputPath)
    $process=Invoke-DynomaxProcess -FilePath $PowerShellPath -Arguments $args -WorkingDirectory $folder -TimeoutSeconds ([int](Get-DynomaxPropertyValue -Object $definition -Name 'timeoutSeconds' -DefaultValue 0)) -ConsoleLogPath (Join-Path $RunDirectory ("action-{0}.console.log" -f $Step.order)) -StreamOutput:$StreamOutput -ShowCommand:$ShowCommand -HeartbeatSeconds $HeartbeatSeconds -DisplayName ("PowerShell action {0}" -f $Step.actionId)
    $isCleanup=[bool](Get-DynomaxPropertyValue -Object $Step -Name 'cleanup' -DefaultValue $false)
    $actionResult=Resolve-DynomaxExternalActionResult -ProcessResult $process -OutputPath $outputPath -IsCleanup:$isCleanup
    Add-DynomaxActionRun -SqlConfig $SqlConfig -RunId $RunId -StepOrder ([int]$Step.order) -ActionKey ([string]$Step.actionId) -Status $actionResult.Status -Message $actionResult.Message -OutputJson $actionResult.OutputJson -IsCleanup:$isCleanup
    return $process
}
