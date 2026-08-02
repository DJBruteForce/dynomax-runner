Set-StrictMode -Version Latest

function Find-DynomaxRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StartPath)

    $current = [System.IO.Path]::GetFullPath($StartPath)
    if (Test-Path -LiteralPath $current -PathType Leaf) {
        $current = Split-Path -Parent $current
    }

    while ($current) {
        if (Test-Path -LiteralPath (Join-Path $current 'dynomax.json') -PathType Leaf) {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }

    throw "Could not locate dynomax.json from '$StartPath'."
}

function Read-DynomaxJson {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file does not exist: $Path"
    }

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "JSON file is empty: $Path" }
    return ($raw | ConvertFrom-Json)
}

function Write-DynomaxJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
    $json = $Value | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-DynomaxSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File does not exist: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-DynomaxTextSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Resolve-DynomaxPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ConfiguredPath
    )

    if ([System.IO.Path]::IsPathRooted($ConfiguredPath)) {
        return [System.IO.Path]::GetFullPath($ConfiguredPath)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $Root $ConfiguredPath))
}

function Ensure-DynomaxDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    [System.IO.Directory]::CreateDirectory($Path) | Out-Null
    return [System.IO.Path]::GetFullPath($Path)
}

function Write-DynomaxLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Debug','Information','Warning','Error','Success')][string]$Level = 'Information',
        [string]$LogPath
    )

    $timestamp = [DateTime]::UtcNow.ToString('o')
    $line = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) {
        'Debug' { 'DarkGray' }
        'Information' { 'Gray' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Success' { 'Green' }
    }
    Write-Host $line -ForegroundColor $color
    if ($LogPath) {
        $directory = Split-Path -Parent $LogPath
        if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
        [System.IO.File]::AppendAllText($LogPath, $line + [Environment]::NewLine, (New-Object System.Text.UTF8Encoding($false)))
    }
}

function Test-DynomaxWindows {
    [CmdletBinding()]
    param()
    return ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT)
}

function Get-DynomaxProjectFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DynomaxRoot,
        [Parameter(Mandatory)][string]$ProjectKey
    )

    $projectsRoot = Join-Path $DynomaxRoot 'Project-Setup'
    $matches = Get-ChildItem -LiteralPath $projectsRoot -Directory -ErrorAction Stop | Where-Object {
        $config = Join-Path $_.FullName 'Project-And-Config\project.json'
        if (-not (Test-Path -LiteralPath $config)) { return $false }
        try { (Read-DynomaxJson -Path $config).projectKey -eq $ProjectKey } catch { $false }
    }

    if (@($matches).Count -ne 1) {
        throw "Expected one project folder for '$ProjectKey', found $(@($matches).Count)."
    }
    return @($matches)[0].FullName
}


function Get-DynomaxPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string]$Name,
        $DefaultValue = $null
    )
    if ($null -eq $Object) { return $DefaultValue }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $DefaultValue }
    return $property.Value
}

function ConvertTo-DynomaxBooleanString {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Value)
    if ([System.Convert]::ToBoolean($Value)) { return 'True' }
    return 'False'
}

function Get-DynomaxUtcNowText { return [DateTime]::UtcNow.ToString('o') }
