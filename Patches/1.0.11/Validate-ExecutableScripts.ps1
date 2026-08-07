[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RootPath,
    [string]$ManifestPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RootPath = [System.IO.Path]::GetFullPath($RootPath)
$files = @()
if ($ManifestPath) {
    $manifest = [System.IO.File]::ReadAllText($ManifestPath) | ConvertFrom-Json
    foreach ($entry in @($manifest.files)) {
        $relative = [string]$entry.path
        if ($relative.EndsWith('.ps1',[System.StringComparison]::OrdinalIgnoreCase)) {
            $files += Join-Path $RootPath ($relative -replace '/', '\\')
        }
    }
}
else {
    $files = @(Get-ChildItem -LiteralPath $RootPath -Filter '*.ps1' -File -Recurse | Select-Object -ExpandProperty FullName)
}
foreach ($file in $files | Sort-Object -Unique) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "PowerShell file was not found: $file" }
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if ($errors.Count -gt 0) {
        $details = ($errors | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Message)" }) -join [Environment]::NewLine
        throw "PowerShell parser errors in '$file':`n$details"
    }
    Write-Host "PASS  PowerShell parse: $file"
}
