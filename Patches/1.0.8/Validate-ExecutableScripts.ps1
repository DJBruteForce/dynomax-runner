[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = [System.IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path -LiteralPath $resolvedRoot)) {
    throw "PowerShell parser gate root was not found: '$resolvedRoot'."
}

$files = @()
if (Test-Path -LiteralPath $resolvedRoot -PathType Leaf) {
    $files = @(Get-Item -LiteralPath $resolvedRoot)
} else {
    $files = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File | Where-Object {
        $_.Extension -in @('.ps1', '.bat', '.cmd')
    })
}

$failureCount = 0
$parsedCount = 0
foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $nonAsciiIndex = -1
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -gt 127) {
            $nonAsciiIndex = $index
            break
        }
    }

    if ($nonAsciiIndex -ge 0) {
        Write-Host ("[ParserGate] NON-ASCII executable: {0}; byte offset {1}; value 0x{2:X2}" -f $file.FullName, $nonAsciiIndex, $bytes[$nonAsciiIndex]) -ForegroundColor Red
        $failureCount++
        continue
    }

    if ($file.Extension -ieq '.ps1') {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        ) | Out-Null
        $parsedCount++

        foreach ($parseError in @($parseErrors)) {
            Write-Host ("[ParserGate] PARSE ERROR: {0}:{1}:{2}: {3}" -f `
                $file.FullName,
                $parseError.Extent.StartLineNumber,
                $parseError.Extent.StartColumnNumber,
                $parseError.Message) -ForegroundColor Red
            $failureCount++
        }
    }
}

if ($failureCount -gt 0) {
    Write-Host ("[ParserGate] FAILED: {0} executable-source defect(s)." -f $failureCount) -ForegroundColor Red
    exit 1
}

Write-Host ("[ParserGate] PASS: {0} executable files checked; {1} PowerShell files parsed by Windows PowerShell {2}." -f $files.Count, $parsedCount, $PSVersionTable.PSVersion) -ForegroundColor Green
exit 0
