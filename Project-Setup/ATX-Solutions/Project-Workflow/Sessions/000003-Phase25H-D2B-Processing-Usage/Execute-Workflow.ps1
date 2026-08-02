[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$commonPath = Join-Path $projectRoot 'Project-And-Config\ATX-Dynomax.Common.ps1'
. $commonPath
$dynomaxRoot = Get-AtxDynomaxRoot -PreferredRoot 'C:\Dynomax'
$contract = Test-AtxDynomaxCoreContract -DynomaxRoot $dynomaxRoot
$startedAtUtc = [DateTime]::UtcNow
Write-Host ("Launching canonical Dynomax workflow runner: {0}" -f $contract.WorkflowRunnerFile)
& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $contract.WorkflowRunnerFile -WorkflowDirectory $PSScriptRoot
$workflowExitCode = $LASTEXITCODE

$exportRoot = Join-Path $dynomaxRoot 'Exports'
$result = $null
foreach ($candidate in @(Get-ChildItem -LiteralPath $exportRoot -Filter '*.zip' -File | Where-Object { $_.LastWriteTimeUtc -ge $startedAtUtc.AddSeconds(-5) } | Sort-Object LastWriteTimeUtc -Descending)) {
    try {
        if (Test-AtxDynomaxResultZip -Path $candidate.FullName -ProjectKey 'atx-solutions' -WorkflowId 'atx.phase25h.d2b.processing-usage') {
            $result = $candidate
            break
        }
    }
    catch {
        Write-Host ("Ignoring non-matching or invalid recent ZIP: {0}" -f $candidate.FullName) -ForegroundColor DarkYellow
    }
}
if ($null -ne $result) {
    Add-Type -AssemblyName System.Windows.Forms
    $dropList = New-Object System.Collections.Specialized.StringCollection
    [void]$dropList.Add($result.FullName)
    [System.Windows.Forms.Clipboard]::SetFileDropList($dropList)
    Write-Host ("Validated every result ZIP entry and declared hash, then copied the ZIP to the clipboard: {0}" -f $result.FullName) -ForegroundColor Green
}
if ($workflowExitCode -ne 0) {
    if ($null -ne $result) { throw "Dynomax workflow runner failed with exit code $workflowExitCode. Result ZIP: $($result.FullName)" }
    throw "Dynomax workflow runner failed with exit code $workflowExitCode and no valid ATX result ZIP was found."
}
if ($null -eq $result) { throw 'No newly generated valid ATX D2-B Dynomax result ZIP was found under C:\Dynomax\Exports.' }
