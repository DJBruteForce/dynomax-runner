[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$DynomaxRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$SourceRoot = [System.IO.Path]::GetFullPath($SourceRoot)
$DynomaxRoot = [System.IO.Path]::GetFullPath($DynomaxRoot)
$resourcePath = Join-Path $SourceRoot 'Core\Robot\Dynomax.resource'
$recorderPath = Join-Path $SourceRoot 'Core\Execution\Record-DynomaxExecutionAttempt.ps1'
foreach ($required in @($resourcePath,$recorderPath,(Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required runtime smoke-test file is missing: $required" }
}
$python = $null
foreach ($candidate in @('py.exe','python.exe')) {
    $command = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($command) { $python = $command.Source; break }
}
if (-not $python) { throw 'Python was not found for the Robot runtime smoke test.' }
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('Dynomax-Core-1.0.11-R4-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    $resourceRobot = $resourcePath.Replace('\','/')

    $suitePath = Join-Path $tempRoot 'wrapper-smoke.robot'
    $suite = @"
*** Settings ***
Resource    $resourceRobot

*** Test Cases ***
Passing Keyword Is Invoked Through Supported Timeout Wrapper
    `${status}    `${message}=    Run Keyword And Ignore Error    Run Dynomax Keyword With Timeout    No Operation    2 seconds
    Should Be Equal    `${status}    PASS

Ordinary Keyword Failure Is Preserved
    `${status}    `${message}=    Run Keyword And Ignore Error    Run Dynomax Keyword With Timeout    Fail    2 seconds
    Should Be Equal    `${status}    FAIL
"@
    [System.IO.File]::WriteAllText($suitePath,$suite,(New-Object System.Text.UTF8Encoding($false)))
    & $python -B -m robot --outputdir (Join-Path $tempRoot 'robot-pass') --output output.xml --log NONE --report NONE $suitePath
    if ([int]$LASTEXITCODE -ne 0) { throw "Robot timeout-wrapper smoke test failed with exit code $LASTEXITCODE." }

    $timeoutSuitePath = Join-Path $tempRoot 'timeout-smoke.robot'
    $timeoutSuite = @"
*** Settings ***
Resource    $resourceRobot

*** Test Cases ***
Timeout Is Enforced
    Run Dynomax Keyword With Timeout    Slow Keyword    50 milliseconds

*** Keywords ***
Slow Keyword
    BuiltIn.Sleep    2 seconds
"@
    [System.IO.File]::WriteAllText($timeoutSuitePath,$timeoutSuite,(New-Object System.Text.UTF8Encoding($false)))
    & $python -B -m robot --outputdir (Join-Path $tempRoot 'robot-timeout') --output output.xml --log NONE --report NONE $timeoutSuitePath *> $null
    if ([int]$LASTEXITCODE -eq 0) { throw 'Robot timeout-wrapper smoke test unexpectedly passed; timeout was not enforced.' }
    $timeoutOutputPath = Join-Path $tempRoot 'robot-timeout\output.xml'
    if (-not (Test-Path -LiteralPath $timeoutOutputPath -PathType Leaf)) { throw 'Robot timeout smoke test did not produce output.xml.' }
    $timeoutOutput = [System.IO.File]::ReadAllText($timeoutOutputPath)
    if ($timeoutOutput.IndexOf('timeout',[System.StringComparison]::OrdinalIgnoreCase) -lt 0) { throw 'Robot timeout-wrapper smoke test failed without a timeout diagnostic.' }

    $runDirectory = Join-Path $tempRoot 'attempt-run'
    [System.IO.Directory]::CreateDirectory($runDirectory) | Out-Null
    $runId = [Guid]::NewGuid()
    $actionVersionId = [Guid]::NewGuid()
    $now = [DateTime]::UtcNow.ToString('o')
    $message64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('expected failure'))
    $arguments = @(
        '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$recorderPath,
        '-DynomaxRoot',$DynomaxRoot,'-RunDirectory',$runDirectory,'-RunId',[string]$runId,
        '-StepOrder','10','-StepId','smoke','-ActionKey','smoke.action','-ActionVersion','1',
        '-ActionVersionId',[string]$actionVersionId,'-AttemptNumber','1','-StartedAtUtc',$now,'-EndedAtUtc',$now,
        '-Status','FAIL','-MessageBase64',$message64,'-RetryOnCsv','Http429',
        '-WaitBeforeExecutionSeconds','0','-DelayBeforeNextAttemptSeconds','0',
        '-BrowserSessionDecision','Reuse','-EvidencePolicy','FinalFailureOnly',
        '-IsFinalAttempt','True','-IsCleanup','False','-TimedOut','False','-SensitiveAction','False',
        '-DeclaredClassification','None'
    )
    $stdout = Join-Path $tempRoot 'recorder.stdout.log'
    $stderr = Join-Path $tempRoot 'recorder.stderr.log'
    & powershell.exe @arguments 1> $stdout 2> $stderr
    $recorderExitCode = [int]$LASTEXITCODE
    if ($recorderExitCode -ne 0) {
        $errorText = if (Test-Path $stderr) { [System.IO.File]::ReadAllText($stderr) } else { '' }
        throw "Attempt-recorder smoke test failed with exit code $recorderExitCode: $errorText"
    }
    $jsonText = [System.IO.File]::ReadAllText($stdout).Trim()
    if ([string]::IsNullOrWhiteSpace($jsonText)) { throw 'Attempt-recorder smoke test returned no JSON.' }
    $result = $jsonText | ConvertFrom-Json
    if ($null -eq $result.retryable) { throw 'Attempt-recorder smoke-test JSON is missing retryable.' }
    if (-not (Test-Path -LiteralPath (Join-Path $runDirectory 'execution-attempts.jsonl') -PathType Leaf)) { throw 'Attempt recorder did not create execution-attempts.jsonl.' }

    Write-Host 'PASS  Robot timeout-wrapper and attempt-recorder runtime smoke tests.' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
