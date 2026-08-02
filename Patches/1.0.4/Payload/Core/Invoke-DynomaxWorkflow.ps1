[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkflowDirectory,
    [string]$DynomaxConfigPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$current=[System.IO.Path]::GetFullPath($WorkflowDirectory)
while($current -and -not(Test-Path(Join-Path $current 'dynomax.json'))){$parent=Split-Path -Parent $current;if($parent -eq $current){break};$current=$parent}
if(-not $current -or -not(Test-Path(Join-Path $current 'dynomax.json'))){throw 'Dynomax root not found.'}
$root=$current
. (Join-Path $root 'Core\Common\Dynomax.Common.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Process.ps1')
. (Join-Path $root 'Core\Database\Dynomax.Database.ps1')
. (Join-Path $root 'Core\Catalogue\Dynomax.Catalogue.ps1')
. (Join-Path $root 'Core\Results\Dynomax.Results.ps1')
. (Join-Path $root 'Core\Execution\Dynomax.Workflow.ps1')
if(-not $DynomaxConfigPath){$DynomaxConfigPath=Join-Path $root 'dynomax.json'}
$config=Read-DynomaxJson -Path $DynomaxConfigPath
$sqlConfigPath=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.databaseConfig
$databaseConfig=Read-DynomaxJson -Path $sqlConfigPath
$sqlConfig=$databaseConfig.sql
$workflowPath=Join-Path $WorkflowDirectory 'workflow.json'
$workflow=Read-DynomaxJson -Path $workflowPath
$projectFolder=Get-DynomaxProjectFolder -DynomaxRoot $root -ProjectKey ([string]$workflow.projectKey)
$projectConfigPath=Join-Path $projectFolder 'Project-And-Config\project.json'
$projectConfig=Read-DynomaxJson -Path $projectConfigPath
Import-DynomaxProjectFolder -ProjectFolder $projectFolder -SqlConfig $sqlConfig
$payloadFolder=Join-Path $WorkflowDirectory 'Payload'
if(Test-Path $payloadFolder){Get-ChildItem -LiteralPath $payloadFolder -Filter action.json -File -Recurse|ForEach-Object{[void](Import-DynomaxActionDefinition -ActionJsonPath $_.FullName -SqlConfig $sqlConfig)}}
[void](Import-DynomaxWorkflowDefinition -WorkflowJsonPath $workflowPath -SqlConfig $sqlConfig)
$packageHash=Get-DynomaxSha256 -Path $workflowPath
$tempRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.tempRuns
$runDirectory=Ensure-DynomaxDirectory -Path (Join-Path $tempRoot ([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')))
$contextPath=Join-Path $runDirectory 'context.json'
$context=[ordered]@{schemaVersion=1;values=[ordered]@{workflowBlocked=$false;projectKey=[string]$workflow.projectKey;environment=[string]$workflow.environment}}
Write-DynomaxJson -Value $context -Path $contextPath
$runId=New-DynomaxTestRun -SqlConfig $sqlConfig -ProjectKey ([string]$workflow.projectKey) -WorkflowKey ([string]$workflow.workflowId) -EnvironmentKey ([string]$workflow.environment) -WorkingDirectory $runDirectory -PackageHash $packageHash
$context.values.runId=[string]$runId
Write-DynomaxJson -Value $context -Path $contextPath
$prereq=Read-DynomaxJson -Path (Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.prerequisiteConfig)
$pythonCandidates=@($prereq.pythonCommandCandidates)
$python=Resolve-DynomaxCommand -Candidates $pythonCandidates
if(-not $python){throw 'Python was not found. Run prerequisite setup.'}
$powerShell=if($PSVersionTable.PSEdition -eq 'Core'){$PSHOME+'\pwsh.exe'}else{$PSHOME+'\powershell.exe'}
$streamProcessOutput=[bool](Get-DynomaxPropertyValue -Object $config.logging -Name 'streamProcessOutput' -DefaultValue $true)
$showProcessCommands=[bool](Get-DynomaxPropertyValue -Object $config.logging -Name 'showProcessCommands' -DefaultValue $false)
$processHeartbeatSeconds=[int](Get-DynomaxPropertyValue -Object $config.logging -Name 'processHeartbeatSeconds' -DefaultValue 15)
$overall='ERROR'
try{
    $steps=@($workflow.steps|Sort-Object order)
    $index=0
    while($index -lt $steps.Count){
        $step=$steps[$index]
        $folder=Resolve-DynomaxActionFolder -ProjectFolder $projectFolder -ActionKey ([string]$step.actionId) -WorkflowDirectory $WorkflowDirectory
        $action=Read-DynomaxJson -Path (Join-Path $folder 'action.json')
        if([string]$action.engine -eq 'RobotBrowser'){
            $block=New-Object System.Collections.Generic.List[object]
            while($index -lt $steps.Count){
                $candidate=$steps[$index]
                $candidateFolder=Resolve-DynomaxActionFolder -ProjectFolder $projectFolder -ActionKey ([string]$candidate.actionId) -WorkflowDirectory $WorkflowDirectory
                $candidateAction=Read-DynomaxJson -Path (Join-Path $candidateFolder 'action.json')
                if([string]$candidateAction.engine -ne 'RobotBrowser'){break}
                $block.Add($candidate);$index++
            }
            $timeout=[int](Get-DynomaxPropertyValue -Object $workflow -Name 'timeoutSeconds' -DefaultValue 0)
            $process=Invoke-DynomaxRobotBlock -DynomaxRoot $root -ProjectFolder $projectFolder -ProjectConfig $projectConfig -Workflow $workflow -Steps $block.ToArray() -RunId $runId -RunDirectory $runDirectory -ContextPath $contextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -PythonPath $python -TimeoutSeconds $timeout -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds
            $outputXml=Join-Path $runDirectory 'robot-result\output.xml'
            if(-not(Test-Path $outputXml)){throw "Robot did not produce output.xml. Exit code: $($process.ExitCode). Error: $($process.StandardError)"}
        } elseif([string]$action.engine -eq 'PowerShell'){
            [void](Invoke-DynomaxPowerShellAction -DynomaxRoot $root -ProjectFolder $projectFolder -RunId $runId -Step $step -ContextPath $contextPath -RunDirectory $runDirectory -WorkflowDirectory $WorkflowDirectory -PowerShellPath $powerShell -SqlConfig $sqlConfig -StreamOutput:$streamProcessOutput -ShowCommand:$showProcessCommands -HeartbeatSeconds $processHeartbeatSeconds)
            $index++
        } else {throw "Unsupported V1 action engine '$($action.engine)' for '$($step.actionId)'."}
    }
    $overall=Get-DynomaxOverallStatus -SqlConfig $sqlConfig -RunId $runId
    Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary "Workflow '$($workflow.displayName)' completed with status $overall."
}
catch{
    $overall='ERROR'
    try{Complete-DynomaxTestRun -SqlConfig $sqlConfig -RunId $runId -Status $overall -Summary $_.Exception.Message}catch{}
    throw
}
finally{
    if(Test-Path $contextPath){try{$finalContext=Read-DynomaxJson -Path $contextPath;Set-DynomaxContextValuesInSql -SqlConfig $sqlConfig -RunId $runId -Context $finalContext}catch{}}
    $artifactIngestionSucceeded=$true
    $max=[long]$config.execution.maximumSqlArtifactBytes
    Get-ChildItem -LiteralPath $runDirectory -File -Recurse -ErrorAction SilentlyContinue | Where-Object{$_.Name -match '^(output\.xml|log\.html|report\.html|robot-console\.log|.*\.png|.*\.stdout\.log|.*\.stderr\.log)$'} | ForEach-Object{
        $artifactFile=$_
        try{[void](Add-DynomaxArtifact -SqlConfig $sqlConfig -RunId $runId -ArtifactType 'RunEvidence' -Path $artifactFile.FullName -MaximumBytes $max)}catch{$artifactIngestionSucceeded=$false;Write-Warning ("Artifact ingestion failed for '{0}': {1}" -f $artifactFile.FullName,$_.Exception.Message)}
    }
    $exportRoot=Resolve-DynomaxPath -Root $root -ConfiguredPath $config.paths.exports
    $summaryDir=Ensure-DynomaxDirectory -Path (Join-Path $runDirectory 'export')
    try{$summary=Export-DynomaxRunSummary -SqlConfig $sqlConfig -RunId $runId -OutputDirectory $summaryDir}catch{$artifactIngestionSucceeded=$false;Write-Warning $_.Exception.Message}
    $projectExport = Join-Path $runDirectory 'project-export'
    if (Test-Path -LiteralPath $projectExport -PathType Container) {
        $projectFindings = Ensure-DynomaxDirectory -Path (Join-Path $summaryDir 'ProjectFindings')
        foreach ($projectFile in Get-ChildItem -LiteralPath $projectExport -File -Recurse) {
            $projectExportPrefix = $projectExport.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
            $relative = $projectFile.FullName.Substring($projectExportPrefix.Length)
            $destination = Join-Path $projectFindings $relative
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
            Copy-Item -LiteralPath $projectFile.FullName -Destination $destination -Force
            try {
                [void](Add-DynomaxArtifact -SqlConfig $sqlConfig -RunId $runId -ArtifactType 'ProjectFinding' -Path $projectFile.FullName -MaximumBytes $max)
            }
            catch {
                $artifactIngestionSucceeded = $false
                Write-Warning ("Project finding ingestion failed for '{0}': {1}" -f $projectFile.FullName, $_.Exception.Message)
            }
        }
    }
    if($overall -ne 'PASS'){
        $selected=Ensure-DynomaxDirectory -Path (Join-Path $summaryDir 'SelectedEvidence')
        foreach($candidate in @((Join-Path $runDirectory 'robot-console.log'),(Join-Path $runDirectory 'robot-result\output.xml'),(Join-Path $runDirectory 'robot-result\log.html'))){if(Test-Path $candidate){Copy-Item -LiteralPath $candidate -Destination $selected -Force}}
        $screens=Join-Path $runDirectory 'screenshots';if(Test-Path $screens){Copy-Item -LiteralPath $screens -Destination (Join-Path $selected 'screenshots') -Recurse -Force}
    }
    if($config.execution.createResultZip){
        Ensure-DynomaxDirectory -Path $exportRoot|Out-Null
        $safeProject=([string]$workflow.projectKey -replace '[^A-Za-z0-9_.-]','_')
        $safeWorkflow=([string]$workflow.workflowId -replace '[^A-Za-z0-9_.-]','_')
        $final=Join-Path $exportRoot ("Dynomax_{0}_{1}_{2}_{3}.zip" -f $safeProject,$safeWorkflow,[DateTime]::UtcNow.ToString('yyyyMMddHHmmss'),$overall)
        $building=$final+'.building.zip'
        if(Test-Path $building){Remove-Item $building -Force}
        Compress-Archive -Path (Join-Path $summaryDir '*') -DestinationPath $building -CompressionLevel Optimal
        if(-not(Test-Path $building) -or (Get-Item $building).Length -le 0){throw 'Result ZIP build failed.'}
        Move-Item -LiteralPath $building -Destination $final -Force
        Write-Host "Result ZIP: $final" -ForegroundColor Green
        if ([bool](Get-DynomaxPropertyValue -Object $config.execution -Name 'copyResultZipToClipboard' -DefaultValue $false)) {
            try {
                Set-DynomaxClipboardFile -Path $final
                Write-Host 'Result ZIP copied to the Windows clipboard.' -ForegroundColor Green
            }
            catch {
                Write-Warning ("Result ZIP was created but could not be copied to the clipboard: {0}" -f $_.Exception.Message)
            }
        }
    }
    if([bool]$config.execution.deleteTemporaryRunAfterSuccessfulIngestion -and $artifactIngestionSucceeded){
        try{Remove-Item -LiteralPath $runDirectory -Recurse -Force}catch{Write-Warning "Could not remove temporary run directory: $($_.Exception.Message)"}
    }
}
Write-Host "Dynomax Run ID: $runId" -ForegroundColor Cyan
Write-Host "Overall Status: $overall" -ForegroundColor $(if($overall -eq 'PASS'){'Green'}else{'Yellow'})
if($overall -ne 'PASS'){
    try{
        $firstProblem=Get-DynomaxFirstProblem -SqlConfig $sqlConfig -RunId $runId
        if($firstProblem){
            Write-Host ("First problem: step {0}, {1}, {2}" -f $firstProblem.StepOrder,$firstProblem.ActionKey,$firstProblem.Status) -ForegroundColor Yellow
            if($firstProblem.Message){Write-Host ("Reason: {0}" -f $firstProblem.Message) -ForegroundColor Yellow}
        }
        else{
            Write-Host 'No action result was persisted. Inspect robot-console.log and output.xml in the result ZIP.' -ForegroundColor Yellow
        }
    }catch{Write-Warning ("Could not read the first workflow problem: {0}" -f $_.Exception.Message)}
}
if($overall -eq 'PASS'){exit 0}else{exit 1}
