Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-AtxDynomaxRoot {
    [CmdletBinding()]
    param([string]$PreferredRoot = 'C:\Dynomax')
    $resolved = [System.IO.Path]::GetFullPath($PreferredRoot)
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Dynomax root was not found: $resolved"
    }
    return $resolved
}

function ConvertTo-AtxVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Value)
    $match = [regex]::Match($Value, '(?<v>\d+\.\d+\.\d+(?:\.\d+)?)')
    if (-not $match.Success) { throw "Unable to parse version from '$Value'." }
    return [version]$match.Groups['v'].Value
}

function Get-AtxDynomaxVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$DynomaxRoot)
    $versionPath = Join-Path $DynomaxRoot 'VERSION.txt'
    if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
        throw "Dynomax VERSION.txt was not found: $versionPath"
    }
    return ConvertTo-AtxVersion -Value ((Get-Content -LiteralPath $versionPath -Raw).Trim())
}

function Get-AtxFileSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}


function Get-AtxExecutableExtensions {
    [CmdletBinding()]
    param()
    return @('.ps1','.bat','.cmd','.resource','.robot')
}

function Test-AtxExecutableContract {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    foreach ($byte in $bytes) {
        if ($byte -gt 127) { throw "Executable contains a non-ASCII byte: $Path" }
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "Executable contains a UTF-8 BOM: $Path"
    }
    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
    if ($text -match '(?<!\r)\n') { throw "Executable contains a non-CRLF line ending: $Path" }
}

function Test-AtxRobotJavaScriptInterpolationContract {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $lineNumber = 0
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $lineNumber++
        $commandIndex = $line.IndexOf('Evaluate JavaScript', [System.StringComparison]::OrdinalIgnoreCase)
        if ($commandIndex -lt 0) { continue }
        $javascript = $line.Substring($commandIndex + 'Evaluate JavaScript'.Length)
        if ($javascript -match '`[^`]*\$\{[^}]+\}[^`]*`') {
            throw ("Robot JavaScript contains template interpolation that Robot can misread as a variable at line {0}: {1}" -f $lineNumber,$Path)
        }
    }
}

function Test-AtxRobotKeywordStructure {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string[]]$Paths)

    $robotFiles = @()
    foreach ($path in @($Paths)) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Robot keyword-structure path is missing: $path" }
        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer) {
            $robotFiles += @(Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force | Where-Object { $_.Extension -in @('.resource','.robot') })
        }
        elseif ($item.Extension -in @('.resource','.robot')) {
            $robotFiles += $item
        }
    }

    $robotFiles = @($robotFiles | Sort-Object FullName -Unique)
    $definitions = @()
    foreach ($file in @($robotFiles)) {
        $section = ''
        $lineNumber = 0
        foreach ($line in [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::ASCII)) {
            $lineNumber++
            $trimmed = $line.Trim()
            if ($trimmed -match '^\*{3}.*\*{3}$') {
                $section = $trimmed.ToLowerInvariant()
                continue
            }
            if ($section -ne '*** keywords ***') { continue }
            if ($line.Length -eq 0 -or [char]::IsWhiteSpace($line[0]) -or $trimmed.StartsWith('#')) { continue }

            $cells = @([regex]::Split($line.TrimEnd(), '(?:\t+| {2,})') | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            if ($cells.Count -ne 1) {
                throw ("Robot keyword header contains unexpected argument cells at {0} line {1}: {2}" -f $file.FullName,$lineNumber,$line)
            }

            $name = [string]$cells[0].Trim()
            $normalized = [regex]::Replace($name.ToLowerInvariant(), '[ _]', '')
            $definitions += [pscustomobject]@{
                Name = $name
                NormalizedName = $normalized
                Path = $file.FullName
                Line = $lineNumber
            }
        }
    }

    $duplicates = @($definitions | Group-Object NormalizedName | Where-Object { $_.Count -gt 1 })
    if ($duplicates.Count -gt 0) {
        $details = @()
        foreach ($duplicate in @($duplicates)) {
            foreach ($definition in @($duplicate.Group)) {
                $details += ("{0} at {1}:{2}" -f $definition.Name,$definition.Path,$definition.Line)
            }
        }
        throw ("Robot keyword name is defined multiple times after Robot normalization: {0}" -f ($details -join '; '))
    }

    Write-Host ("Robot keyword structure passed: {0} headers, {1} unique normalized names, 0 malformed headers." -f $definitions.Count,$definitions.Count)
    return @($definitions)
}

function Test-AtxPowerShellParser {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $first = $errors[0]
        throw ("PowerShell parser error in {0} at line {1}, column {2}: {3}" -f $Path,$first.Extent.StartLineNumber,$first.Extent.StartColumnNumber,$first.Message)
    }
}

function Test-AtxMatchesAutomaticVariableCollision {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { return }
    $reservedVariableUses = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $node.VariablePath.UserPath -ieq 'Matches'
    }, $true))
    if ($reservedVariableUses.Count -gt 0) {
        $firstUse = $reservedVariableUses[0]
        throw ("PowerShell file uses the reserved automatic Matches variable at line {0}, column {1}: {2}" -f $firstUse.Extent.StartLineNumber,$firstUse.Extent.StartColumnNumber,$Path)
    }
}

function Test-AtxPackageTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RootPath,
        [Parameter(Mandatory=$true)][string]$ManifestPath
    )
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $declared = @{}
    foreach ($entry in $manifest.files) {
        $relativeForward = if ($entry.PSObject.Properties['sourcePath']) { [string]$entry.sourcePath } else { [string]$entry.path }
        if ($relativeForward -match '\\') { throw "Manifest path contains a backslash: $relativeForward" }
        if ($declared.ContainsKey($relativeForward)) { throw "Manifest path is duplicated: $relativeForward" }
        $declared[$relativeForward] = $true
        $relative = $relativeForward.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $full = Join-Path $RootPath $relative
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Manifest file is missing: $relative" }
        if ((Get-Item -LiteralPath $full).Length -ne [int64]$entry.size) { throw "Manifest size mismatch for $relative" }
        if ((Get-AtxFileSha256 -Path $full) -ine [string]$entry.sha256) { throw "Manifest hash mismatch for $relative" }
    }
    foreach ($file in (Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force)) {
        $relative = $file.FullName.Substring($RootPath.Length).TrimStart('\','/').Replace('\','/')
        if ($relative -ieq 'PACKAGE_MANIFEST.json') { continue }
        if (-not $declared.ContainsKey($relative)) { throw "Package contains an undeclared file: $relative" }
    }
    foreach ($file in (Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force | Where-Object { $_.Extension -in @(Get-AtxExecutableExtensions) })) {
        Test-AtxExecutableContract -Path $file.FullName
        if ($file.Extension -ieq '.ps1') {
            Test-AtxPowerShellParser -Path $file.FullName
            Test-AtxMatchesAutomaticVariableCollision -Path $file.FullName
        }
        elseif ($file.Extension -in @('.resource','.robot')) {
            Test-AtxRobotJavaScriptInterpolationContract -Path $file.FullName
        }
    }
    [void](Test-AtxRobotKeywordStructure -Paths @($RootPath))
    foreach ($file in (Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.json' -Force)) {
        [void](Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json)
    }
}

function Get-AtxStringProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$InputObject,
        [string]$Prefix = '',
        [int]$Depth = 0
    )
    if ($Depth -gt 16 -or $null -eq $InputObject) { return @() }
    $results = @()
    if ($InputObject -is [string]) { return @() }
    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [pscustomobject])) {
        $index = 0
        foreach ($item in $InputObject) {
            $results += Get-AtxStringProperties -InputObject $item -Prefix ("{0}[{1}]" -f $Prefix,$index) -Depth ($Depth + 1)
            $index++
        }
        return @($results)
    }
    foreach ($property in $InputObject.PSObject.Properties) {
        $path = if ([string]::IsNullOrWhiteSpace($Prefix)) { $property.Name } else { "$Prefix.$($property.Name)" }
        if ($property.Value -is [string]) {
            $results += [pscustomobject]@{ Name=$property.Name; Path=$path; Value=[string]$property.Value }
        }
        elseif ($null -ne $property.Value -and -not ($property.Value -is [ValueType])) {
            $results += Get-AtxStringProperties -InputObject $property.Value -Prefix $path -Depth ($Depth + 1)
        }
    }
    return @($results)
}

function Find-AtxStringProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$InputObject,
        [Parameter(Mandatory=$true)][string[]]$CandidateNames
    )
    foreach ($property in (Get-AtxStringProperties -InputObject $InputObject)) {
        foreach ($candidate in $CandidateNames) {
            if ($property.Name -ieq $candidate -and -not [string]::IsNullOrWhiteSpace($property.Value)) {
                return [string]$property.Value
            }
        }
    }
    return $null
}

function Get-AtxDynomaxDatabaseConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$DynomaxRoot)

    $dynomaxConfigPath = Join-Path $DynomaxRoot 'dynomax.json'
    $coreCommonPath = Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1'
    $coreDatabasePath = Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1'
    foreach ($requiredPath in @($dynomaxConfigPath,$coreCommonPath,$coreDatabasePath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "Required Dynomax configuration or Core file is missing: $requiredPath"
        }
    }

    [void](Test-AtxFunctionContract -Path $coreCommonPath -FunctionName 'Read-DynomaxJson' -RequiredParameters @('Path'))
    [void](Test-AtxFunctionContract -Path $coreCommonPath -FunctionName 'Resolve-DynomaxPath' -RequiredParameters @('Root','ConfiguredPath'))
    [void](Test-AtxFunctionContract -Path $coreDatabasePath -FunctionName 'Open-DynomaxConnection' -RequiredParameters @('SqlConfig'))

    . $coreCommonPath
    . $coreDatabasePath

    $dynomaxConfig = Read-DynomaxJson -Path $dynomaxConfigPath
    if ($null -eq $dynomaxConfig.paths -or [string]::IsNullOrWhiteSpace([string]$dynomaxConfig.paths.databaseConfig)) {
        throw 'dynomax.json does not define paths.databaseConfig.'
    }
    $databaseConfigPath = Resolve-DynomaxPath -Root $DynomaxRoot -ConfiguredPath ([string]$dynomaxConfig.paths.databaseConfig)
    if (-not (Test-Path -LiteralPath $databaseConfigPath -PathType Leaf)) {
        throw "Configured Dynomax database JSON was not found: $databaseConfigPath"
    }
    $databaseConfig = Read-DynomaxJson -Path $databaseConfigPath
    if ($databaseConfig.PSObject.Properties.Name -notcontains 'sql' -or $null -eq $databaseConfig.sql) {
        throw "Configured Dynomax database JSON has no top-level sql object: $databaseConfigPath"
    }
    return [pscustomobject]@{
        Path = $databaseConfigPath
        DatabaseConfig = $databaseConfig
        SqlConfig = $databaseConfig.sql
        CoreCommonPath = $coreCommonPath
        CoreDatabasePath = $coreDatabasePath
    }
}

function Test-AtxDynomaxSqlConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$DynomaxRoot)

    $databaseInfo = Get-AtxDynomaxDatabaseConfiguration -DynomaxRoot $DynomaxRoot

    # Dot-source the Core dependencies in this function scope. PowerShell functions
    # loaded inside Get-AtxDynomaxDatabaseConfiguration do not escape that helper's
    # local scope after it returns.
    . $databaseInfo.CoreCommonPath
    . $databaseInfo.CoreDatabasePath
    $openConnectionCommand = Get-Command Open-DynomaxConnection -CommandType Function -ErrorAction SilentlyContinue
    if ($null -eq $openConnectionCommand) {
        throw "Open-DynomaxConnection was not loaded into the SQL validation scope from: $($databaseInfo.CoreDatabasePath)"
    }

    $connection = Open-DynomaxConnection -SqlConfig $databaseInfo.SqlConfig
    try {
        $command = $connection.CreateCommand()
        $command.CommandText = 'SELECT DB_NAME() AS DatabaseName, @@SERVERNAME AS ServerName;'
        $reader = $command.ExecuteReader()
        try {
            if (-not $reader.Read()) { throw 'Dynomax SQL validation returned no row.' }
            $databaseName = [string]$reader['DatabaseName']
            if ($databaseName -ine 'Dynomax') { throw "Configured SQL database is '$databaseName', expected 'Dynomax'." }
            return [pscustomobject]@{
                DatabaseName = $databaseName
                ServerName = [string]$reader['ServerName']
                DatabaseConfigPath = $databaseInfo.Path
                SqlConfig = $databaseInfo.SqlConfig
            }
        }
        finally { $reader.Dispose() }
    }
    finally { $connection.Dispose() }
}

function Get-AtxPowerShellAst {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $first = $errors[0]
        throw ("PowerShell parser error in installed Core file {0} at line {1}, column {2}: {3}" -f $Path,$first.Extent.StartLineNumber,$first.Extent.StartColumnNumber,$first.Message)
    }
    return $ast
}

function Test-AtxFunctionContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$FunctionName,
        [Parameter(Mandatory=$true)][string[]]$RequiredParameters
    )
    $ast = Get-AtxPowerShellAst -Path $Path
    $functionDefinitions = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -ieq $FunctionName }, $true))
    if ($functionDefinitions.Count -ne 1) { throw "Expected exactly one $FunctionName function in $Path; found $($functionDefinitions.Count)." }
    $parameters = @()
    if ($null -ne $functionDefinitions[0].Body.ParamBlock) {
        foreach ($parameter in $functionDefinitions[0].Body.ParamBlock.Parameters) { $parameters += $parameter.Name.VariablePath.UserPath }
    }
    foreach ($required in $RequiredParameters) {
        if (-not ($parameters -icontains $required)) { throw "$FunctionName in $Path is missing required parameter $required." }
    }
    return @($parameters)
}

function Test-AtxScriptContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string[]]$RequiredParameters
    )
    $ast = Get-AtxPowerShellAst -Path $Path
    $parameters = @()
    if ($null -ne $ast.ParamBlock) {
        foreach ($parameter in $ast.ParamBlock.Parameters) { $parameters += $parameter.Name.VariablePath.UserPath }
    }
    foreach ($required in $RequiredParameters) {
        if (-not ($parameters -icontains $required)) { throw "Script $Path is missing required parameter $required." }
    }
    return @($parameters)
}

function Test-AtxDynomaxCoreContract {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$DynomaxRoot)
    $catalogue = Join-Path $DynomaxRoot 'Core\Catalogue\Dynomax.Catalogue.ps1'
    $allocator = Join-Path $DynomaxRoot 'Core\Catalogue\New-DynomaxWorkflowSession.ps1'
    $runner = Join-Path $DynomaxRoot 'Core\Invoke-DynomaxWorkflow.ps1'
    $coreCommon = Join-Path $DynomaxRoot 'Core\Common\Dynomax.Common.ps1'
    $coreDatabase = Join-Path $DynomaxRoot 'Core\Database\Dynomax.Database.ps1'
    $coreProcess = Join-Path $DynomaxRoot 'Core\Execution\Dynomax.Process.ps1'
    foreach ($path in @($catalogue,$allocator,$runner,$coreCommon,$coreDatabase,$coreProcess)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Dynomax 1.0.8 Core file is missing: $path" }
    }
    [void](Test-AtxFunctionContract -Path $coreCommon -FunctionName 'Read-DynomaxJson' -RequiredParameters @('Path'))
    [void](Test-AtxFunctionContract -Path $coreCommon -FunctionName 'Resolve-DynomaxPath' -RequiredParameters @('Root','ConfiguredPath'))
    [void](Test-AtxFunctionContract -Path $coreProcess -FunctionName 'Resolve-DynomaxCommand' -RequiredParameters @('Candidates'))
    [void](Test-AtxFunctionContract -Path $coreDatabase -FunctionName 'Open-DynomaxConnection' -RequiredParameters @('SqlConfig'))
    [void](Test-AtxFunctionContract -Path $catalogue -FunctionName 'Import-DynomaxProjectFolder' -RequiredParameters @('ProjectFolder','SqlConfig'))
    [void](Test-AtxFunctionContract -Path $catalogue -FunctionName 'Import-DynomaxProjectDefinition' -RequiredParameters @('ProjectJsonPath','SqlConfig'))
    [void](Test-AtxFunctionContract -Path $catalogue -FunctionName 'Import-DynomaxActionDefinition' -RequiredParameters @('ActionJsonPath','SqlConfig'))
    [void](Test-AtxFunctionContract -Path $catalogue -FunctionName 'Import-DynomaxWorkflowDefinition' -RequiredParameters @('WorkflowJsonPath','SqlConfig'))
    [void](Test-AtxScriptContract -Path $allocator -RequiredParameters @('ProjectKey','Name'))
    [void](Test-AtxScriptContract -Path $runner -RequiredParameters @('WorkflowDirectory','DynomaxConfigPath'))
    return [pscustomobject]@{
        ProjectImportFunction='Import-DynomaxProjectFolder'
        ProjectImportFile=$catalogue
        SessionAllocatorFile=$allocator
        WorkflowRunnerFile=$runner
        CoreCommonFile=$coreCommon
        CoreProcessFile=$coreProcess
        CoreDatabaseFile=$coreDatabase
    }
}

function Test-AtxDynomaxResultZip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$ProjectKey,
        [Parameter(Mandatory=$true)][string]$WorkflowId
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $required = @('RunSummary.json','RunSummary.md','ActionResults.json','ContextSnapshot.json','Assertions.json','Events.json','CleanupSummary.json','ArtifactManifest.json','WorkflowManifest.json','TemporaryWorkspaceCleanup.json','DynomaxExportManifest.json')
        $entries = @{}
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -match '\\') { throw "Result ZIP contains a backslash member path: $($entry.FullName)" }
            $name = $entry.FullName.Replace('\','/')
            if ($entries.ContainsKey($name)) { throw "Result ZIP contains a duplicate member: $name" }
            $entries[$name] = $entry
            $stream = $entry.Open()
            try {
                $buffer = New-Object byte[] 8192
                while ($stream.Read($buffer,0,$buffer.Length) -gt 0) {}
            }
            finally { $stream.Dispose() }
        }
        foreach ($name in $required) { if (-not $entries.ContainsKey($name)) { throw "Result ZIP is missing required entry: $name" } }
        foreach ($prefix in @('Definitions/','TestEvidence/')) {
            $found = $false
            foreach ($name in $entries.Keys) { if ($name.StartsWith($prefix,[System.StringComparison]::Ordinal)) { $found = $true; break } }
            if (-not $found) { throw "Result ZIP is missing required content prefix: $prefix" }
        }
        $workflowEntry = $entries['WorkflowManifest.json']
        $workflowStream = $workflowEntry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($workflowStream,[System.Text.Encoding]::UTF8,$true,4096,$true)
            try { $workflowManifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        }
        finally { $workflowStream.Dispose() }
        $actualProjectKey = Find-AtxStringProperty -InputObject $workflowManifest -CandidateNames @('projectKey')
        $actualWorkflowId = Find-AtxStringProperty -InputObject $workflowManifest -CandidateNames @('workflowId')
        if ($actualProjectKey -ine $ProjectKey -or $actualWorkflowId -ine $WorkflowId) { return $false }
        $exportEntry = $entries['DynomaxExportManifest.json']
        $exportStream = $exportEntry.Open()
        try {
            $reader = New-Object System.IO.StreamReader($exportStream,[System.Text.Encoding]::UTF8,$true,4096,$true)
            try { $exportManifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        }
        finally { $exportStream.Dispose() }
        $declaredFiles = @()
        foreach ($propertyName in @('files','entries','artifacts','members')) {
            if ($exportManifest.PSObject.Properties.Name -contains $propertyName) {
                $declaredFiles = @($exportManifest.$propertyName)
                if ($declaredFiles.Count -gt 0) { break }
            }
        }
        if ($declaredFiles.Count -eq 0) { throw 'DynomaxExportManifest.json contains no declared files.' }
        foreach ($declared in $declaredFiles) {
            $declaredPath = $null
            foreach ($name in @('path','zipPath','memberPath','fileName','name')) {
                if ($declared.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$declared.$name)) { $declaredPath = [string]$declared.$name; break }
            }
            if ([string]::IsNullOrWhiteSpace($declaredPath)) { throw 'A Dynomax export manifest entry has no path.' }
            $declaredPath = $declaredPath.Replace('\','/')
            if (-not $entries.ContainsKey($declaredPath)) { throw "Declared ZIP member is missing: $declaredPath" }
            $entry = $entries[$declaredPath]
            if ($declared.PSObject.Properties.Name -contains 'size' -and [int64]$declared.size -ne $entry.Length) { throw "Declared size mismatch: $declaredPath" }
            if ($declared.PSObject.Properties.Name -contains 'sha256') {
                $sha = [System.Security.Cryptography.SHA256]::Create()
                $stream = $entry.Open()
                try { $actualHash = ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
                finally { $stream.Dispose(); $sha.Dispose() }
                if ($actualHash -ine [string]$declared.sha256) { throw "Declared SHA-256 mismatch: $declaredPath" }
            }
        }
        return $true
    }
    finally { $archive.Dispose() }
}
