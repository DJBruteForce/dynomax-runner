Set-StrictMode -Version Latest

$script:DynomaxBuiltInCoreContractPolicy = $null

function Get-DynomaxBuiltInCoreContractPolicy {
    [CmdletBinding()]
    param()

    if ($null -ne $script:DynomaxBuiltInCoreContractPolicy) {
        return $script:DynomaxBuiltInCoreContractPolicy
    }

    $manifestPath = Join-Path $PSScriptRoot 'BUILTIN_CORE_CONTRACTS.json'
    $legacySupported = @('1.0.15','1.0.16','1.0.17')
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $script:DynomaxBuiltInCoreContractPolicy = [pscustomobject]@{
            ManifestPath = $manifestPath
            InstalledCoreVersion = '1.0.20'
            SupportedRequiredCoreVersions = $legacySupported
            LegacyFallback = $true
        }
        return $script:DynomaxBuiltInCoreContractPolicy
    }

    try {
        $policy = Read-DynomaxJson -Path $manifestPath
        $schemaVersion = [int](Get-DynomaxPropertyValue -Object $policy -Name 'schemaVersion' -DefaultValue 0)
        $declaredCoreVersion = [string](Get-DynomaxPropertyValue -Object $policy -Name 'coreVersion' -DefaultValue '')
        $versions = @((Get-DynomaxPropertyValue -Object $policy -Name 'supportedRequiredCoreVersions' -DefaultValue @()) |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique)
        $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $versionPath = Join-Path $root 'VERSION.txt'
        $runtimeContractPath = Join-Path $root 'Core\RUNTIME_CONTRACT.json'
        $installedRuntimeRevision = if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
            ([string](Get-Content -LiteralPath $versionPath -Raw)).Trim()
        } else { '' }
        if (-not (Test-Path -LiteralPath $runtimeContractPath -PathType Leaf)) {
            throw 'The Dynomax Core runtime contract is missing while validating the Built-in Core contract policy.'
        }
        $runtimeContract = Read-DynomaxJson -Path $runtimeContractPath
        $runtimeContractSchemaVersion = [int](Get-DynomaxPropertyValue -Object $runtimeContract -Name 'schemaVersion' -DefaultValue 0)
        $installedCoreVersion = [string](Get-DynomaxPropertyValue -Object $runtimeContract -Name 'coreVersion' -DefaultValue '')
        $runtimeContractRevision = [string](Get-DynomaxPropertyValue -Object $runtimeContract -Name 'runtimeRevision' -DefaultValue '')
        if ($schemaVersion -ne 1 -or -not $declaredCoreVersion -or $versions.Count -lt 1 -or
            $runtimeContractSchemaVersion -ne 1 -or -not $installedCoreVersion -or
            $declaredCoreVersion -cne $installedCoreVersion -or
            -not $installedRuntimeRevision -or -not $runtimeContractRevision -or
            $runtimeContractRevision -cne $installedRuntimeRevision) {
            throw 'The Built-in Core contract policy does not match the installed Dynomax Core semantic version/runtime revision identity.'
        }
        $script:DynomaxBuiltInCoreContractPolicy = [pscustomobject]@{
            ManifestPath = $manifestPath
            InstalledCoreVersion = $installedCoreVersion
            InstalledRuntimeRevision = $installedRuntimeRevision
            SupportedRequiredCoreVersions = $versions
            LegacyFallback = $false
        }
        return $script:DynomaxBuiltInCoreContractPolicy
    }
    catch {
        $exception = New-Object System.InvalidOperationException('Dynomax Core Built-in contract policy is invalid.', $_.Exception)
        $exception.Data['DynomaxErrorCode'] = 'CORE_BUILTIN_CONTRACT_POLICY_INVALID'
        $exception.Data['DynomaxArtifactType'] = 'CoreContractPolicy'
        $exception.Data['DynomaxArtifactPath'] = 'Core/Execution/BUILTIN_CORE_CONTRACTS.json'
        $exception.Data['DynomaxCorrectiveAction'] = 'Reinstall the exact validated Dynomax Core package before executing Built-in Actions.'
        throw $exception
    }
}

function Assert-DynomaxCoreRuntimeContract {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DynomaxRoot)

    $manifestPath = Join-Path $DynomaxRoot 'Core\RUNTIME_CONTRACT.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $exception = New-Object System.InvalidOperationException('Dynomax Core 1.0.20 is missing the compiler 1.19.15 continuation runtime contract.')
        $exception.Data['DynomaxErrorCode'] = 'CORE_RUNTIME_CONTRACT_MISSING'
        $exception.Data['DynomaxArtifactType'] = 'CoreRuntimeContract'
        $exception.Data['DynomaxArtifactPath'] = 'Core/RUNTIME_CONTRACT.json'
        $exception.Data['DynomaxRequiredCoreVersion'] = '1.0.20'
        $exception.Data['DynomaxCorrectiveAction'] = 'Install the complete Dynomax Core 1.0.20 R20.7.9 overlay before executing compiler 1.19.15 publications.'
        throw $exception
    }

    try {
        $manifest = Read-DynomaxJson -Path $manifestPath
        $schemaVersion = [int](Get-DynomaxPropertyValue -Object $manifest -Name 'schemaVersion' -DefaultValue 0)
        $coreVersion = [string](Get-DynomaxPropertyValue -Object $manifest -Name 'coreVersion' -DefaultValue '')
        $runtimeRevision = [string](Get-DynomaxPropertyValue -Object $manifest -Name 'runtimeRevision' -DefaultValue '')
        $compilerVersions = @((Get-DynomaxPropertyValue -Object $manifest -Name 'compilerVersions' -DefaultValue @()) | ForEach-Object { [string]$_ })
        $capabilities = @((Get-DynomaxPropertyValue -Object $manifest -Name 'capabilities' -DefaultValue @()) | ForEach-Object { [string]$_ })
        if ($schemaVersion -ne 1 -or $coreVersion -cne '1.0.20' -or $runtimeRevision -cne 'R20.7.9' -or
            '1.19.15' -notin $compilerVersions -or
            'continuation-decision-v1' -notin $capabilities -or
            'cleanup-execution-order-v1' -notin $capabilities -or
            'cleanup-stop-on-failure-v1' -notin $capabilities -or
            'cleanup-transition-fast-path-v1' -notin $capabilities -or
            'run-contract-finalization-recovery-v1' -notin $capabilities -or
            'run-data-pool-delta-persistence-v1' -notin $capabilities -or
            'runtime-context-cache-v1' -notin $capabilities -or
            'control-flow-checkpoint-v1' -notin $capabilities -or
            'compact-robot-schedule-v1' -notin $capabilities -or
            'result-definition-deduplication-v1' -notin $capabilities -or
            'control-flow-event-batch-v1' -notin $capabilities -or
            'context-value-batch-persistence-v1' -notin $capabilities -or
            'result-evidence-compaction-v1' -notin $capabilities -or
            'structured-form-actions-v1' -notin $capabilities) {
            throw 'Runtime contract identity/capability mismatch.'
        }

        $files = @((Get-DynomaxPropertyValue -Object $manifest -Name 'files' -DefaultValue @()))
        foreach ($requiredPath in @('Core/Robot/Dynomax.resource','Core/Robot/DynomaxContext.py','Core/Execution/Dynomax.Workflow.ps1','Core/Invoke-DynomaxWorkflow.ps1')) {
            $matches = @($files | Where-Object { [string](Get-DynomaxPropertyValue -Object $_ -Name 'path' -DefaultValue '') -ceq $requiredPath })
            if ($matches.Count -ne 1) { throw "Runtime contract does not contain exactly one closure entry for '$requiredPath'." }
            $entry = $matches[0]
            $expectedLength = [long](Get-DynomaxPropertyValue -Object $entry -Name 'length' -DefaultValue -1)
            $expectedSha = ([string](Get-DynomaxPropertyValue -Object $entry -Name 'sha256' -DefaultValue '')).ToLowerInvariant()
            $relativeOsPath = $requiredPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $fullPath = Join-Path $DynomaxRoot $relativeOsPath
            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Required continuation runtime file '$requiredPath' is missing." }
            $actualLength = [long](Get-Item -LiteralPath $fullPath).Length
            $actualSha = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($expectedLength -lt 1 -or $expectedSha.Length -ne 64 -or $actualLength -ne $expectedLength -or $actualSha -cne $expectedSha) {
                throw "Required continuation runtime file '$requiredPath' does not match the runtime contract."
            }
        }
    }
    catch {
        if ($_.Exception.Data.Contains('DynomaxErrorCode')) { throw }
        $exception = New-Object System.InvalidOperationException('Dynomax Core continuation runtime contract is invalid or incomplete.', $_.Exception)
        $exception.Data['DynomaxErrorCode'] = 'CORE_RUNTIME_CONTRACT_INVALID'
        $exception.Data['DynomaxArtifactType'] = 'CoreRuntimeContract'
        $exception.Data['DynomaxArtifactPath'] = 'Core/RUNTIME_CONTRACT.json'
        $exception.Data['DynomaxRequiredCoreVersion'] = '1.0.20'
        $exception.Data['DynomaxCorrectiveAction'] = 'Reinstall the complete Dynomax Core 1.0.20 R20.7.9 overlay before executing compiler 1.19.15 publications.'
        throw $exception
    }
}

function New-DynomaxBuiltInClosureException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Code,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][int]$ContractVersion,
        [Parameter(Mandatory)][string]$ArtifactType,
        [Parameter(Mandatory)][string]$Message,
        [string]$ArtifactPath,
        [string]$RequiredCoreVersion,
        [string]$InstalledCoreVersion,
        [string]$ExpectedDefinitionSha256,
        [string]$ActualDefinitionSha256,
        [string]$ExpectedEntryPointSha256,
        [string]$ActualEntryPointSha256,
        [string]$ExpectedValue,
        [string]$ActualValue,
        [string]$CorrectiveAction = 'Reinstall the exact immutable Built-in package/Core combination or repair the publication from authoritative source bytes.'
    )

    $exception = New-Object System.InvalidOperationException($Message)
    $exception.Data['DynomaxErrorCode'] = $Code
    $exception.Data['DynomaxArtifactType'] = $ArtifactType
    if ($ArtifactPath) { $exception.Data['DynomaxArtifactPath'] = $ArtifactPath }
    $exception.Data['DynomaxBuiltInActionKey'] = $ActionKey
    $exception.Data['DynomaxBuiltInContractVersion'] = [string]$ContractVersion
    if ($RequiredCoreVersion) { $exception.Data['DynomaxRequiredCoreVersion'] = $RequiredCoreVersion }
    if ($InstalledCoreVersion) { $exception.Data['DynomaxInstalledCoreVersion'] = $InstalledCoreVersion }
    if ($ExpectedDefinitionSha256) { $exception.Data['DynomaxExpectedDefinitionSha256'] = $ExpectedDefinitionSha256 }
    if ($ActualDefinitionSha256) { $exception.Data['DynomaxActualDefinitionSha256'] = $ActualDefinitionSha256 }
    if ($ExpectedEntryPointSha256) { $exception.Data['DynomaxExpectedEntryPointSha256'] = $ExpectedEntryPointSha256 }
    if ($ActualEntryPointSha256) { $exception.Data['DynomaxActualEntryPointSha256'] = $ActualEntryPointSha256 }
    if ($ExpectedValue) { $exception.Data['DynomaxExpectedValue'] = $ExpectedValue }
    if ($ActualValue) { $exception.Data['DynomaxActualValue'] = $ActualValue }
    $exception.Data['DynomaxCorrectiveAction'] = $CorrectiveAction
    return $exception
}

function New-DynomaxExecutionPlanException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Classification,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][string]$Message,
        [Guid]$ActionVersionId = [Guid]::Empty,
        [hashtable]$Metadata
    )

    $exception = New-Object System.InvalidOperationException($Message)
    $exception.Data['DynomaxClassification'] = $Classification
    $exception.Data['DynomaxStepOrder'] = $StepOrder
    $exception.Data['DynomaxActionKey'] = $ActionKey
    if ($ActionVersionId -ne [Guid]::Empty) {
        $exception.Data['DynomaxActionVersionId'] = [string]$ActionVersionId
    }
    if ($null -ne $Metadata) {
        foreach ($item in $Metadata.GetEnumerator()) {
            if ($null -ne $item.Value) { $exception.Data[[string]$item.Key] = [string]$item.Value }
        }
    }
    return $exception
}

function Throw-DynomaxExecutionPlanIssue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Classification,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][string]$Message,
        [Guid]$ActionVersionId = [Guid]::Empty,
        [hashtable]$Metadata
    )

    throw (New-DynomaxExecutionPlanException -Classification $Classification -StepOrder $StepOrder -ActionKey $ActionKey -Message $Message -ActionVersionId $ActionVersionId -Metadata $Metadata)
}

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

function Assert-DynomaxBuiltInPackageSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Definition,
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$DefinitionHash,
        [Parameter(Mandatory)][string]$EntryPointHash
    )
    $origin=[string](Get-DynomaxPropertyValue -Object $Definition -Name 'actionOrigin' -DefaultValue '')
    if($origin -ne 'BuiltIn'){return}
    $runtimeKey=[string](Get-DynomaxPropertyValue -Object $Definition -Name 'actionId' -DefaultValue '')
    $canonicalKey=[string](Get-DynomaxPropertyValue -Object $Definition -Name 'canonicalActionId' -DefaultValue '')
    $canonicalDefinitionHash=[string](Get-DynomaxPropertyValue -Object $Definition -Name 'canonicalDefinitionSha256' -DefaultValue '')
    $contractVersion=[int](Get-DynomaxPropertyValue -Object $Definition -Name 'builtInContractVersion' -DefaultValue 0)
    $requiredCore=[string](Get-DynomaxPropertyValue -Object $Definition -Name 'requiredCoreVersion' -DefaultValue '')
    $entryPoint=[string](Get-DynomaxPropertyValue -Object $Definition -Name 'entryPoint' -DefaultValue '')
    $manifestRelativePath='BUILTIN_PACKAGE_MANIFEST.json'
    $manifestPath=Join-Path $Folder $manifestRelativePath
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_MANIFEST_MISSING' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'PackageManifest' -ArtifactPath $manifestRelativePath -RequiredCoreVersion $requiredCore -Message "Built-in Action '$canonicalKey' v$contractVersion package manifest is missing." -CorrectiveAction 'Re-materialize the exact immutable Built-in package from the source-owned catalogue before running it.')
    }
    $manifest=Read-DynomaxJson -Path $manifestPath
    $checks=@(
        @{Code='BUILTIN_MANIFEST_TYPE_MISMATCH';Name='packageType';Expected='DynomaxBuiltInActionPackage';Actual=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'packageType' -DefaultValue '');Type='PackageManifest'},
        @{Code='BUILTIN_MANIFEST_ORIGIN_MISMATCH';Name='actionOrigin';Expected='BuiltIn';Actual=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'actionOrigin' -DefaultValue '');Type='PackageManifest'},
        @{Code='BUILTIN_MANIFEST_ACTION_KEY_MISMATCH';Name='actionKey';Expected=$canonicalKey;Actual=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'actionKey' -DefaultValue '');Type='ActionIdentity'},
        @{Code='BUILTIN_MANIFEST_RUNTIME_KEY_MISMATCH';Name='runtimeActionKey';Expected=$runtimeKey;Actual=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'runtimeActionKey' -DefaultValue '');Type='ActionIdentity'},
        @{Code='BUILTIN_MANIFEST_VERSION_MISMATCH';Name='contractVersion';Expected=[string]$contractVersion;Actual=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'contractVersion' -DefaultValue 0);Type='ActionIdentity'},
        @{Code='BUILTIN_REQUIRED_CORE_MISMATCH';Name='requiredCoreVersion';Expected=$requiredCore;Actual=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'requiredCoreVersion' -DefaultValue '');Type='CoreContract'}
    )
    foreach($check in $checks){
        if([string]$check.Expected -cne [string]$check.Actual){
            throw (New-DynomaxBuiltInClosureException -Code $check.Code -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType $check.Type -ArtifactPath $manifestRelativePath -RequiredCoreVersion $requiredCore -ExpectedValue ([string]$check.Expected) -ActualValue ([string]$check.Actual) -Message "Built-in Action '$canonicalKey' v$contractVersion package manifest field '$($check.Name)' does not match its exact immutable identity.")
        }
    }
    $manifestDefinitionHash=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'definitionSha256' -DefaultValue '')
    if(-not $canonicalKey -or -not $canonicalDefinitionHash -or $manifestDefinitionHash -ine $canonicalDefinitionHash){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_DEFINITION_HASH_MISMATCH' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'Definition' -ArtifactPath $manifestRelativePath -RequiredCoreVersion $requiredCore -ExpectedDefinitionSha256 $canonicalDefinitionHash -ActualDefinitionSha256 $manifestDefinitionHash -Message "Built-in Action '$canonicalKey' v$contractVersion definition hash does not match its exact immutable package manifest.")
    }
    $manifestRuntimeDefinitionHash=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'runtimeDefinitionSha256' -DefaultValue '')
    if($manifestRuntimeDefinitionHash -notmatch '^[0-9a-fA-F]{64}$'){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_RUNTIME_DEFINITION_HASH_INVALID' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'RuntimeDefinition' -ArtifactPath $manifestRelativePath -RequiredCoreVersion $requiredCore -ActualValue $manifestRuntimeDefinitionHash -Message "Built-in Action '$canonicalKey' v$contractVersion runtime-definition hash is missing or invalid.")
    }
    $manifestEntryPointHash=[string](Get-DynomaxPropertyValue -Object $manifest -Name 'entryPointSha256' -DefaultValue '')
    if($manifestEntryPointHash -ine $EntryPointHash){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_ENTRYPOINT_HASH_MISMATCH' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'EntryPoint' -ArtifactPath $entryPoint -RequiredCoreVersion $requiredCore -ExpectedEntryPointSha256 $manifestEntryPointHash -ActualEntryPointSha256 $EntryPointHash -Message "Built-in Action '$canonicalKey' v$contractVersion entry-point hash does not match its exact immutable package manifest.")
    }
    $corePolicy=Get-DynomaxBuiltInCoreContractPolicy
    if(@($corePolicy.SupportedRequiredCoreVersions) -cnotcontains $requiredCore){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_CORE_CONTRACT_UNSUPPORTED' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'CoreContract' -ArtifactPath 'Core/Execution/BUILTIN_CORE_CONTRACTS.json' -RequiredCoreVersion $requiredCore -InstalledCoreVersion ([string]$corePolicy.InstalledCoreVersion) -ExpectedValue $requiredCore -ActualValue (@($corePolicy.SupportedRequiredCoreVersions) -join ',') -Message "Installed Dynomax Core '$($corePolicy.InstalledCoreVersion)' does not advertise support for Built-in Action '$canonicalKey' v$contractVersion required Core contract '$requiredCore'." -CorrectiveAction "Install a validated Dynomax Core package whose Built-in contract policy includes '$requiredCore'; do not weaken immutable Action/package checks.")
    }
    if([bool](Get-DynomaxPropertyValue -Object $manifest -Name 'secretValuesIncluded' -DefaultValue $true)){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_MANIFEST_SECRET_POLICY_INVALID' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'PackageManifest' -ArtifactPath $manifestRelativePath -RequiredCoreVersion $requiredCore -Message "Built-in Action '$canonicalKey' v$contractVersion package manifest may not contain secret values.")
    }
    $manifestFiles=@((Get-DynomaxPropertyValue -Object $manifest -Name 'files' -DefaultValue @()))
    if($manifestFiles.Count -lt 1 -or -not @($manifestFiles | Where-Object { [string](Get-DynomaxPropertyValue -Object $_ -Name 'path' -DefaultValue '') -ceq $entryPoint })){
        throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_ENTRYPOINT_MANIFEST_MISSING' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'PackageManifest' -ArtifactPath $manifestRelativePath -RequiredCoreVersion $requiredCore -Message "Built-in Action '$canonicalKey' v$contractVersion package manifest does not include its exact entry point '$entryPoint'.")
    }
    foreach($file in $manifestFiles){
        $relative=[string](Get-DynomaxPropertyValue -Object $file -Name 'path' -DefaultValue '')
        $expected=[string](Get-DynomaxPropertyValue -Object $file -Name 'sha256' -DefaultValue '')
        if(-not $relative -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){
            throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_PACKAGE_PATH_UNSAFE' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'PackageFile' -ArtifactPath $relative -RequiredCoreVersion $requiredCore -Message "Built-in Action '$canonicalKey' v$contractVersion package manifest contains an unsafe file path.")
        }
        $path=Join-Path $Folder $relative
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){
            throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_PACKAGE_FILE_MISSING' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'PackageFile' -ArtifactPath $relative -RequiredCoreVersion $requiredCore -ExpectedValue $expected -ActualValue 'missing' -Message "Built-in Action '$canonicalKey' v$contractVersion package file '$relative' is missing.")
        }
        $actual=Get-DynomaxSha256 -Path $path
        if(-not $expected -or $actual -ine $expected){
            throw (New-DynomaxBuiltInClosureException -Code 'BUILTIN_PACKAGE_FILE_HASH_MISMATCH' -ActionKey $canonicalKey -ContractVersion $contractVersion -ArtifactType 'PackageFile' -ArtifactPath $relative -RequiredCoreVersion $requiredCore -ExpectedValue $expected -ActualValue $actual -Message "Built-in Action '$canonicalKey' v$contractVersion package file '$relative' failed SHA-256 verification.")
        }
    }
}

function Get-DynomaxActionSourceFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$ActionJsonFile,
        [Parameter(Mandatory)][string]$SourceLocation
    )

    $definition = Read-DynomaxJson -Path $ActionJsonFile.FullName
    $entryPointName = [string](Get-DynomaxPropertyValue -Object $definition -Name 'entryPoint' -DefaultValue '')
    if ([string]::IsNullOrWhiteSpace($entryPointName)) {
        throw "Action definition is missing entryPoint: $($ActionJsonFile.FullName)"
    }

    $entryPointPath = Join-Path $ActionJsonFile.Directory.FullName $entryPointName
    if (-not (Test-Path -LiteralPath $entryPointPath -PathType Leaf)) {
        throw "Action entry point does not exist: $entryPointPath"
    }

    $canonical = $definition | ConvertTo-Json -Depth 100 -Compress
    $definitionHash=Get-DynomaxTextSha256 -Text $canonical
    $implementationHash=Get-DynomaxSha256 -Path $entryPointPath
    Assert-DynomaxBuiltInPackageSource -Definition $definition -Folder $ActionJsonFile.Directory.FullName -DefinitionHash $definitionHash -EntryPointHash $implementationHash
    return [pscustomobject]@{
        Folder = $ActionJsonFile.Directory.FullName
        SourceLocation = $SourceLocation
        Definition = $definition
        DefinitionPath = $ActionJsonFile.FullName
        EntryPointPath = $entryPointPath
        DefinitionHash = $definitionHash
        DefinitionFileSha256 = Get-DynomaxSha256 -Path $ActionJsonFile.FullName
        ImplementationHash = $implementationHash
    }
}

function Get-DynomaxActionSourceCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][int]$StepOrder,
        [string]$WorkflowDirectory,
        [string]$WorkflowNodeId,
        [Nullable[int]]$ActionVersionNumber
    )

    $candidates = [System.Collections.Generic.List[object]]::new()
    $locations = @()
    if ($WorkflowDirectory) {
        $payload = Join-Path $WorkflowDirectory 'Payload'
        if (Test-Path -LiteralPath $payload -PathType Container) {
            $locations += [pscustomobject]@{ Path = $payload; Name = 'Payload' }
        }
    }

    $library = Join-Path $ProjectFolder 'Project-Library'
    if (Test-Path -LiteralPath $library -PathType Container) {
        $locations += [pscustomobject]@{ Path = $library; Name = 'Project-Library' }
    }

    foreach ($location in $locations) {
        foreach ($file in Get-ChildItem -LiteralPath $location.Path -Filter action.json -File -Recurse | Sort-Object FullName) {
            try {
                $definition = Read-DynomaxJson -Path $file.FullName
                if ([string]$definition.actionId -ne $ActionKey) { continue }
                $candidates.Add((Get-DynomaxActionSourceFingerprint -ActionJsonFile $file -SourceLocation $location.Name))
            }
            catch {
                $metadata=@{}
                foreach($key in @($_.Exception.Data.Keys)){
                    $name=[string]$key
                    if($name.StartsWith('Dynomax',[System.StringComparison]::Ordinal) -and $null -ne $_.Exception.Data[$key]){
                        $metadata[$name]=[string]$_.Exception.Data[$key]
                    }
                }
                if($WorkflowNodeId){$metadata['DynomaxWorkflowNodeId']=$WorkflowNodeId}
                if($null -ne $ActionVersionNumber){$metadata['DynomaxActionVersionNumber']=[string]$ActionVersionNumber}
                $safeSource="[$($location.Name)]/$($file.Directory.Name)/action.json"
                $metadata['DynomaxArtifactSource']=$safeSource
                $message = "Action source '$safeSource' could not be fingerprinted: $($_.Exception.Message)"
                Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $StepOrder -ActionKey $ActionKey -Message $message -Metadata $metadata
            }
        }
    }

    return $candidates.ToArray()
}

function Resolve-DynomaxActionExecutionSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)][string]$ProjectKey,
        [Parameter(Mandatory)]$Step,
        [Parameter(Mandatory)][object]$SqlConfig,
        [string]$WorkflowDirectory
    )

    $stepOrder = [int]$Step.order
    $actionKey = [string]$Step.actionId
    $requestedRaw = Get-DynomaxPropertyValue -Object $Step -Name 'actionVersion' -DefaultValue $null
    $hasRequestedVersion = $null -ne $requestedRaw -and -not [string]::IsNullOrWhiteSpace([string]$requestedRaw)
    $requestedVersion = if ($hasRequestedVersion) { [int]$requestedRaw } else { $null }
    $catalogue = if ($hasRequestedVersion) { Get-DynomaxActionVersionRecord -SqlConfig $SqlConfig -ProjectKey $ProjectKey -ActionKey $actionKey -RequestedActionVersion $requestedVersion } else { Get-DynomaxActionVersionRecord -SqlConfig $SqlConfig -ProjectKey $ProjectKey -ActionKey $actionKey }

    if ($null -eq $catalogue) {
        if ($hasRequestedVersion) {
            Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $stepOrder -ActionKey $actionKey -Message "Action '$actionKey' version $requestedVersion was not found in the Dynomax catalogue for project '$ProjectKey'."
        }
        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $stepOrder -ActionKey $actionKey -Message "Action '$actionKey' has no current catalogue version for project '$ProjectKey'."
    }

    if ($hasRequestedVersion) {
        $workflowNodeId=[string](Get-DynomaxPropertyValue -Object $Step -Name 'workflowNodeId' -DefaultValue $actionKey)
        $candidates = @(Get-DynomaxActionSourceCandidates -ProjectFolder $ProjectFolder -ActionKey $actionKey -StepOrder $stepOrder -WorkflowDirectory $WorkflowDirectory -WorkflowNodeId $workflowNodeId -ActionVersionNumber $requestedVersion)
        $payloadMatches = @($candidates | Where-Object {
            $_.SourceLocation -eq 'Payload' -and
            $_.DefinitionHash -ieq $catalogue.DefinitionHash -and
            $_.ImplementationHash -ieq $catalogue.ImplementationHash
        })
        $libraryMatches = @($candidates | Where-Object {
            $_.SourceLocation -eq 'Project-Library' -and
            $_.DefinitionHash -ieq $catalogue.DefinitionHash -and
            $_.ImplementationHash -ieq $catalogue.ImplementationHash
        })

        if ($payloadMatches.Count -gt 1) {
            Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $catalogue.ActionVersionId -Message "Workflow payload contains more than one exact source match for '$actionKey' version $requestedVersion."
        }
        if ($libraryMatches.Count -gt 1) {
            Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $catalogue.ActionVersionId -Message "Project library contains more than one exact source match for '$actionKey' version $requestedVersion."
        }

        $selected = if ($payloadMatches.Count -eq 1) { $payloadMatches[0] } elseif ($libraryMatches.Count -eq 1) { $libraryMatches[0] } else { $null }
        if ($null -eq $selected) {
            $found = @($candidates | ForEach-Object { "[$($_.SourceLocation)] definition=$($_.DefinitionHash), implementation=$($_.ImplementationHash), path=$($_.Folder)" })
            $foundText = if ($found.Count -eq 0) { 'No matching action source folders were found.' } else { $found -join '; ' }
            $message = "Pinned action '$actionKey' version $requestedVersion requires definition hash '$($catalogue.DefinitionHash)' and implementation hash '$($catalogue.ImplementationHash)', but the exact source bytes are unavailable. $foundText"
            Throw-DynomaxExecutionPlanIssue -Classification 'STALE' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $catalogue.ActionVersionId -Message $message
        }

        return [pscustomobject]@{
            StepOrder = $stepOrder
            ActionKey = $actionKey
            RequestedActionVersion = $requestedVersion
            ActionVersionId = $catalogue.ActionVersionId
            ResolvedActionVersion = $catalogue.VersionNumber
            Engine = $catalogue.Engine
            EntryPoint = $catalogue.EntryPoint
            KeywordName = $catalogue.KeywordName
            SessionBehavior = $catalogue.SessionBehavior
            DefinitionHash = $catalogue.DefinitionHash
            DefinitionFileSha256 = $selected.DefinitionFileSha256
            ImplementationHash = $catalogue.ImplementationHash
            Folder = $selected.Folder
            DefinitionPath = $selected.DefinitionPath
            EntryPointPath = $selected.EntryPointPath
            SourceLocation = $selected.SourceLocation
            SourceVerified = $true
        }
    }

    $legacyFolder = Resolve-DynomaxActionFolder -ProjectFolder $ProjectFolder -ActionKey $actionKey -WorkflowDirectory $WorkflowDirectory
    $legacyFile = Get-Item -LiteralPath (Join-Path $legacyFolder 'action.json')
    $legacy = Get-DynomaxActionSourceFingerprint -ActionJsonFile $legacyFile -SourceLocation $(if ($WorkflowDirectory -and $legacyFolder.StartsWith((Join-Path $WorkflowDirectory 'Payload'),[System.StringComparison]::OrdinalIgnoreCase)) { 'Payload' } else { 'Project-Library' })
    return [pscustomobject]@{
        StepOrder = $stepOrder
        ActionKey = $actionKey
        RequestedActionVersion = $null
        ActionVersionId = $catalogue.ActionVersionId
        ResolvedActionVersion = $catalogue.VersionNumber
        Engine = [string]$legacy.Definition.engine
        EntryPoint = [string]$legacy.Definition.entryPoint
        KeywordName = $(if (Get-DynomaxPropertyValue -Object $legacy.Definition -Name 'keyword' -DefaultValue $null) { [string]$legacy.Definition.keyword } else { $null })
        SessionBehavior = [string](Get-DynomaxPropertyValue -Object $legacy.Definition -Name 'sessionBehavior' -DefaultValue 'DoesNotUseBrowser')
        DefinitionHash = $catalogue.DefinitionHash
        DefinitionFileSha256 = $legacy.DefinitionFileSha256
        ImplementationHash = $catalogue.ImplementationHash
        Folder = $legacy.Folder
        DefinitionPath = $legacy.DefinitionPath
        EntryPointPath = $legacy.EntryPointPath
        SourceLocation = $legacy.SourceLocation
        SourceVerified = ($legacy.DefinitionHash -ieq $catalogue.DefinitionHash -and $legacy.ImplementationHash -ieq $catalogue.ImplementationHash)
    }
}

function Set-DynomaxStepExecutionMetadata {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Step,[Parameter(Mandatory)]$Plan)

    $properties = [ordered]@{
        DynomaxActionFolder = [string]$Plan.Folder
        DynomaxActionVersionId = [string]$Plan.ActionVersionId
        DynomaxRequestedActionVersion = $Plan.RequestedActionVersion
        DynomaxResolvedActionVersion = [int]$Plan.ResolvedActionVersion
        DynomaxEngine = [string]$Plan.Engine
        DynomaxSessionBehavior = [string]$Plan.SessionBehavior
        DynomaxDefinitionHash = [string]$Plan.DefinitionHash
        DynomaxDefinitionFileSha256 = [string]$Plan.DefinitionFileSha256
        DynomaxImplementationHash = [string]$Plan.ImplementationHash
        DynomaxSourceLocation = [string]$Plan.SourceLocation
        DynomaxSourceVerified = [bool]$Plan.SourceVerified
    }
    foreach ($property in $properties.GetEnumerator()) {
        Add-Member -InputObject $Step -MemberType NoteProperty -Name $property.Key -Value $property.Value -Force
    }
}

function Get-DynomaxStepActionFolder {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Step,[Parameter(Mandatory)][string]$ProjectFolder,[string]$WorkflowDirectory)

    $resolved = Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxActionFolder' -DefaultValue $null
    if ($resolved) { return [string]$resolved }
    return Resolve-DynomaxActionFolder -ProjectFolder $ProjectFolder -ActionKey ([string]$Step.actionId) -WorkflowDirectory $WorkflowDirectory
}

function Assert-DynomaxActionExecutionSourceUnchanged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Step,
        [Parameter(Mandatory)][string]$ProjectFolder,
        [string]$WorkflowDirectory
    )

    $stepOrder = [int]$Step.order
    $actionKey = [string]$Step.actionId
    $actionVersionIdText = [string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxActionVersionId' -DefaultValue '')
    $actionVersionId = if ($actionVersionIdText) { [Guid]$actionVersionIdText } else { [Guid]::Empty }
    $folder = Get-DynomaxStepActionFolder -Step $Step -ProjectFolder $ProjectFolder -WorkflowDirectory $WorkflowDirectory
    $actionJsonPath = Join-Path $folder 'action.json'

    if (-not (Test-Path -LiteralPath $actionJsonPath -PathType Leaf)) {
        Throw-DynomaxExecutionPlanIssue -Classification 'STALE' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $actionVersionId -Message "Action source changed after preflight: '$actionJsonPath' no longer exists."
    }

    $sourceLocation = [string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxSourceLocation' -DefaultValue 'Unknown')
    try {
        $fingerprint = Get-DynomaxActionSourceFingerprint -ActionJsonFile (Get-Item -LiteralPath $actionJsonPath) -SourceLocation $sourceLocation
    }
    catch {
        Throw-DynomaxExecutionPlanIssue -Classification 'STALE' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $actionVersionId -Message "Action source changed after preflight and can no longer be verified: $($_.Exception.Message)"
    }

    $requestedVersion = Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxRequestedActionVersion' -DefaultValue $null
    $isPinned = $null -ne $requestedVersion -and -not [string]::IsNullOrWhiteSpace([string]$requestedVersion)
    if ($isPinned) {
        $expectedDefinitionHash = [string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxDefinitionHash' -DefaultValue '')
        $expectedDefinitionFileSha256 = [string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxDefinitionFileSha256' -DefaultValue '')
        $expectedImplementationHash = [string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxImplementationHash' -DefaultValue '')
        $mismatches = New-Object System.Collections.Generic.List[string]

        if ([string]$fingerprint.Definition.actionId -cne $actionKey) {
            $mismatches.Add("actionId expected '$actionKey' but found '$([string]$fingerprint.Definition.actionId)'")
        }
        if (-not $expectedDefinitionHash -or $fingerprint.DefinitionHash -ine $expectedDefinitionHash) {
            $mismatches.Add("definition hash expected '$expectedDefinitionHash' but found '$($fingerprint.DefinitionHash)'")
        }
        if (-not $expectedDefinitionFileSha256 -or $fingerprint.DefinitionFileSha256 -ine $expectedDefinitionFileSha256) {
            $mismatches.Add("action.json SHA-256 expected '$expectedDefinitionFileSha256' but found '$($fingerprint.DefinitionFileSha256)'")
        }
        if (-not $expectedImplementationHash -or $fingerprint.ImplementationHash -ine $expectedImplementationHash) {
            $mismatches.Add("implementation hash expected '$expectedImplementationHash' but found '$($fingerprint.ImplementationHash)'")
        }

        if ($mismatches.Count -gt 0) {
            $versionText = [string]$requestedVersion
            $message = "Pinned action '$actionKey' version $versionText changed after preflight and execution was stopped before the action started: $($mismatches -join '; ')."
            Throw-DynomaxExecutionPlanIssue -Classification 'STALE' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $actionVersionId -Message $message
        }
    }

    return $fingerprint
}

function Assert-DynomaxVersionPinnedSessionPlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Steps)

    $pinnedSteps = @($Steps | Where-Object {
        $value = Get-DynomaxPropertyValue -Object $_ -Name 'actionVersion' -DefaultValue $null
        $null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)
    })
    if ($pinnedSteps.Count -eq 0) { return }
    if ($pinnedSteps.Count -ne $Steps.Count) {
        $firstUnpinned = @($Steps | Where-Object {
            $value = Get-DynomaxPropertyValue -Object $_ -Name 'actionVersion' -DefaultValue $null
            $null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)
        } | Sort-Object order | Select-Object -First 1)[0]
        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder ([int]$firstUnpinned.order) -ActionKey ([string]$firstUnpinned.actionId) -Message "A version-pinned workflow must specify actionVersion on every normal and cleanup step. Step '$($firstUnpinned.actionId)' is unpinned."
    }

    $normalSteps=@($Steps | Where-Object { -not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false) })
    $cleanupSteps=@($Steps | Where-Object { [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false) })
    $preserveCleanupBrowserSession=$normalSteps.Count -gt 0 -and $cleanupSteps.Count -gt 0
    if($preserveCleanupBrowserSession){
        foreach($candidate in @($normalSteps)+@($cleanupSteps)){
            if([string](Get-DynomaxPropertyValue -Object $candidate -Name 'DynomaxEngine' -DefaultValue '') -ne 'RobotBrowser'){$preserveCleanupBrowserSession=$false;break}
        }
    }
    if($preserveCleanupBrowserSession){
        foreach($candidate in $cleanupSteps){
            if([string](Get-DynomaxPropertyValue -Object $candidate -Name 'DynomaxSessionBehavior' -DefaultValue 'DoesNotUseBrowser') -eq 'RequiresNewBrowser'){$preserveCleanupBrowserSession=$false;break}
        }
    }

    foreach ($section in @(
        [pscustomobject]@{ Name='normal'; Steps=@($Steps | Where-Object { -not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false) } | Sort-Object order) },
        [pscustomobject]@{ Name='cleanup'; Steps=@($Steps | Where-Object { [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false) } | Sort-Object order -Descending) }
    )) {
        $robotBlockCount = 0
        $insideRobotBlock = $false
        $robotVersionByActionKey = @{}
        foreach ($step in @($section.Steps)) {
            $order = [int]$step.order
            $key = [string]$step.actionId
            $versionIdText = [string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue '')
            $versionId = if ($versionIdText) { [Guid]$versionIdText } else { [Guid]::Empty }
            $engine = [string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxEngine' -DefaultValue '')
            $session = [string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxSessionBehavior' -DefaultValue 'DoesNotUseBrowser')

            if ($section.Name -eq 'normal' -and [bool](Get-DynomaxPropertyValue -Object $step -Name 'continueOnFailure' -DefaultValue $false)) {
                Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Version-pinned workflows are fail-fast in Dynomax Core 1.0.16. Step '$key' cannot set continueOnFailure=true."
            }

            if ($engine -notin @('RobotBrowser','PowerShell')) {
                Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Action '$key' uses unsupported engine '$engine'."
            }
            if ($engine -eq 'RobotBrowser') {
                if ($session -notin @('RequiresNewBrowser','RequiresExistingBrowser','RequiresNewOrExistingBrowser','DoesNotUseBrowser')) {
                    Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "RobotBrowser action '$key' has unsupported session behavior '$session'."
                }
                if ($robotVersionByActionKey.ContainsKey($key) -and [string]$robotVersionByActionKey[$key] -ne [string]$versionId) {
                    Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "The $($section.Name) Robot block requests more than one version of action '$key'. Core 1.0.16 cannot load two resource versions with the same Robot keyword into one shared browser suite."
                }
                $robotVersionByActionKey[$key] = [string]$versionId
                if (-not $insideRobotBlock) {
                    $robotBlockCount++
                    if ($robotBlockCount -gt 1) {
                        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "The $($section.Name) plan contains more than one Robot browser block. Dynomax Core 1.0.16 supports one contiguous Robot block per normal or cleanup section."
                    }
                    if ($session -eq 'RequiresExistingBrowser' -and -not ($section.Name -eq 'cleanup' -and $preserveCleanupBrowserSession)) {
                        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Action '$key' requires an existing browser, but no compatible preserved Main browser is available for the $($section.Name) Robot block."
                    }
                    $insideRobotBlock = $true
                }
                elseif ($session -eq 'RequiresNewBrowser') {
                    Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Action '$key' requires a new browser inside an existing Robot block. Mid-block browser replacement is not supported."
                }
            }
            else {
                if ($session -ne 'DoesNotUseBrowser') {
                    Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Non-browser action '$key' must declare DoesNotUseBrowser."
                }
                $insideRobotBlock = $false
            }
        }
    }
}

function ConvertTo-DynomaxRobotCellValue {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return '${EMPTY}' }
    $text = [string]$Value
    if ($text.Length -eq 0) { return '${EMPTY}' }
    return $text
}

function New-DynomaxRobotSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DynomaxRoot,[Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)]$ProjectConfig,[Parameter(Mandatory)]$Workflow,[Parameter(Mandatory)][object[]]$Steps,
        [Parameter(Mandatory)][Guid]$RunId,[Parameter(Mandatory)][string]$RunDirectory,[Parameter(Mandatory)][string]$ContextPath,
        [Parameter(Mandatory)][string]$WorkflowDirectory,[Parameter(Mandatory)][string]$PowerShellPath,
        [bool]$PreserveCleanupBrowserSession=$false
    )
    $resourcePaths=@()
    $actionDefinitions=@{}
    $fingerprintsByActionVersionId=@{}
    foreach($step in $Steps){
        $actionVersionCacheKey=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue '')
        if($actionVersionCacheKey -and $fingerprintsByActionVersionId.ContainsKey($actionVersionCacheKey)){
            $fingerprint=$fingerprintsByActionVersionId[$actionVersionCacheKey]
        }else{
            $fingerprint=Assert-DynomaxActionExecutionSourceUnchanged -Step $step -ProjectFolder $ProjectFolder -WorkflowDirectory $WorkflowDirectory
            if($actionVersionCacheKey){$fingerprintsByActionVersionId[$actionVersionCacheKey]=$fingerprint}
        }
        $folder=[string]$fingerprint.Folder
        $definition=$fingerprint.Definition
        if([string]$definition.engine -ne 'RobotBrowser'){throw "Action '$($step.actionId)' is not RobotBrowser."}
        if(-not $definition.keyword){throw "Robot action '$($step.actionId)' is missing keyword."}
        $entry=[string]$fingerprint.EntryPointPath
        $resourcePaths += [System.IO.Path]::GetFullPath($entry).Replace('\','/')
        $actionDefinitions[[string][int]$step.order]=$definition
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
    $attemptRecorderScript=[System.IO.Path]::GetFullPath((Join-Path $DynomaxRoot 'Core\Execution\Record-DynomaxExecutionAttempt.ps1')).Replace('\','/')
    $controlFlowScript=[System.IO.Path]::GetFullPath((Join-Path $DynomaxRoot 'Core\Execution\Invoke-DynomaxControlFlow.ps1')).Replace('\','/')
    $workflowPathForward=[System.IO.Path]::GetFullPath((Join-Path $WorkflowDirectory 'workflow.json')).Replace('\','/')
    $rootForward=[System.IO.Path]::GetFullPath($DynomaxRoot).Replace('\','/')
    $runForward=[System.IO.Path]::GetFullPath($RunDirectory).Replace('\','/')
    $contextForward=[System.IO.Path]::GetFullPath($ContextPath).Replace('\','/')
    $psForward=[System.IO.Path]::GetFullPath($PowerShellPath).Replace('\','/')
    $controlFlowConfig=Get-DynomaxPropertyValue -Object $Workflow -Name 'controlFlow' -DefaultValue $null
    $controlFlowEnabled=$null -ne $controlFlowConfig
    $containsMainStep=@($Steps|Where-Object{-not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)}).Count -gt 0
    $containsCleanupStep=@($Steps|Where-Object{[bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)}).Count -gt 0
    $useControlFlowDriver=$controlFlowEnabled -and $containsMainStep
    $usePreservedCleanupDriver=$useControlFlowDriver -and $PreserveCleanupBrowserSession -and $containsCleanupStep
    $lines=New-Object System.Collections.Generic.List[string]
    $lines.Add('*** Settings ***')
    $lines.Add("Resource    $coreResource")
    foreach($resource in ($resourcePaths|Select-Object -Unique)){$lines.Add("Resource    $resource")}
    $lines.Add('Suite Setup    Start Dynomax Browser')
    $lines.Add('Suite Teardown    Complete Dynomax Browser Suite')
    if(-not $useControlFlowDriver){$lines.Add('Test Teardown    Persist Dynomax Robot Action Result')}
    $lines.Add('')
    $lines.Add('*** Variables ***')
    $lines.Add("`${DYNOMAX_ROOT}    $rootForward")
    $lines.Add("`${DYNOMAX_RUN_ID}    $RunId")
    $lines.Add("`${DYNOMAX_RUN_DIR}    $runForward")
    $lines.Add("`${DYNOMAX_CONTEXT_PATH}    $contextForward")
    $lines.Add("`${DYNOMAX_PERSIST_SCRIPT}    $persistScript")
    $lines.Add("`${DYNOMAX_ATTEMPT_RECORDER_SCRIPT}    $attemptRecorderScript")
    $lines.Add("`${DYNOMAX_CONTROL_FLOW_SCRIPT}    $controlFlowScript")
    $lines.Add("`${DYNOMAX_WORKFLOW_PATH}    $workflowPathForward")
    $lines.Add("`${DYNOMAX_POWERSHELL}    $psForward")
    $lines.Add("`${DYNOMAX_BASE_URL}    $baseUrl")
    $lines.Add("`${DYNOMAX_BROWSER}    $browser")
    $lines.Add("`${DYNOMAX_HEADLESS}    $headless")
    $lines.Add("`${DYNOMAX_VIEWPORT}    $viewport")
    $discoveryConfig=Get-DynomaxPropertyValue -Object $Workflow -Name 'discovery' -DefaultValue $null
    $discoveryEnabled=if($discoveryConfig){ConvertTo-DynomaxBooleanString (Get-DynomaxPropertyValue -Object $discoveryConfig -Name 'enabled' -DefaultValue $false)}else{'False'}
    $discoveryTargetNodeId=if($discoveryConfig){[string](Get-DynomaxPropertyValue -Object $discoveryConfig -Name 'targetNodeId' -DefaultValue '')}else{''}
    $lines.Add("`${DYNOMAX_DISCOVERY_ENABLED}    $discoveryEnabled")
    $lines.Add("`${DYNOMAX_DISCOVERY_TARGET_NODE_ID}    $discoveryTargetNodeId")
    $lines.Add("`${DYNOMAX_CONTROL_FLOW_ENABLED}    $(if($controlFlowEnabled){'True'}else{'False'})")
    $lines.Add("`${DYNOMAX_CONTROL_FLOW_TERMINAL}    False")
    $lines.Add("`${DYNOMAX_CLEANUP_STOP_REQUESTED}    False")
    $lines.Add("`${DYNOMAX_ACTION_METADATA_READY}    False")
    $lines.Add('')
    $lines.Add('*** Test Cases ***')
    # Invoke-DynomaxStepSequence has already established semantic execution order: Main is ascending,
    # Cleanup is descending so the Cleanup graph start executes first. Never re-sort $Steps here.
    if($useControlFlowDriver){
        # A pre-unrolled bounded-control-flow schedule can contain hundreds or thousands of
        # physical execution slots. Keep Main in one Robot test so terminal control flow jumps
        # immediately rather than visiting every unselected physical slot. When Cleanup shares
        # the Main browser, execute Cleanup as a second generated phase inside the same Robot
        # test/browser lifecycle and return immediately on StopCleanup.
        $driverMainSteps=@($Steps|Where-Object{-not [bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)})
        $driverCleanupSteps=@($Steps|Where-Object{[bool](Get-DynomaxPropertyValue -Object $_ -Name 'cleanup' -DefaultValue $false)})
        $lines.Add('Dynomax Workflow')
        $lines.Add('    Execute Dynomax Control Flow Schedule')
        $lines.Add('')
        $lines.Add('*** Keywords ***')
        $lines.Add('Execute Dynomax Control Flow Schedule')
        foreach($scheduledStep in $driverMainSteps){
            $slotKeyword=('Execute Dynomax Physical Slot {0:D6}' -f [int]$scheduledStep.order)
            $lines.Add("    $slotKeyword")
            $lines.Add("    IF    `${DYNOMAX_CONTROL_FLOW_TERMINAL}")
            if($usePreservedCleanupDriver){$lines.Add('        Execute Dynomax Cleanup Schedule')}
            $lines.Add('        RETURN')
            $lines.Add('    END')
        }
        if($usePreservedCleanupDriver){
            $lines.Add('    Execute Dynomax Cleanup Schedule')
        }
        $lines.Add('    RETURN')
        $lines.Add('')
        if($usePreservedCleanupDriver){
            $lines.Add('Execute Dynomax Cleanup Schedule')
            foreach($scheduledStep in $driverCleanupSteps){
                $slotKeyword=('Execute Dynomax Physical Slot {0:D6}' -f [int]$scheduledStep.order)
                $lines.Add("    $slotKeyword")
                $lines.Add("    IF    `${DYNOMAX_CLEANUP_STOP_REQUESTED}")
                $lines.Add('        RETURN')
                $lines.Add('    END')
            }
            $lines.Add('    RETURN')
            $lines.Add('')
        }

        foreach($step in $Steps){
            $definition=$actionDefinitions[[string][int]$step.order]
            $isCleanup=[bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)
            if($isCleanup -and -not $usePreservedCleanupDriver){continue}
            $cleanup=if($isCleanup){'True'}else{'False'}
            $requestedVersion=Get-DynomaxPropertyValue -Object $step -Name 'DynomaxRequestedActionVersion' -DefaultValue $null
            $requestedText=if($null -eq $requestedVersion){''}else{[string]$requestedVersion}
            $requestedRobotCell=ConvertTo-DynomaxRobotCellValue -Value $requestedText
            $resolvedVersion=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxResolvedActionVersion' -DefaultValue '')
            $actionVersionId=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue '')
            if(-not $actionVersionId){throw "Action '$($step.actionId)' has no preflight action-version ID."}
            $stepId=[string](Get-DynomaxPropertyValue -Object $step -Name 'stepId' -DefaultValue ("step-{0}" -f $step.order))
            $workflowNodeId=[string](Get-DynomaxPropertyValue -Object $step -Name 'workflowNodeId' -DefaultValue $stepId)
            $executionSlot=[int](Get-DynomaxPropertyValue -Object $step -Name 'executionSlot' -DefaultValue 1)
            $outputSpecs=@((Get-DynomaxPropertyValue -Object $definition -Name 'outputs' -DefaultValue @())|ForEach-Object{[ordered]@{name=[string](Get-DynomaxPropertyValue -Object $_ -Name 'name' -DefaultValue '');classification=[string](Get-DynomaxPropertyValue -Object $_ -Name 'classification' -DefaultValue 'Normal');persistInResult=[bool](Get-DynomaxPropertyValue -Object $_ -Name 'persistInResult' -DefaultValue $true);sensitiveWhenInputsSensitive=@(Get-DynomaxPropertyValue -Object $_ -Name 'sensitiveWhenInputsSensitive' -DefaultValue @())}})
            $outputSpecsJson=ConvertTo-Json -InputObject $outputSpecs -Depth 10 -Compress
            $outputSpecsB64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($outputSpecsJson))
            $continueOnFailure=if([bool](Get-DynomaxPropertyValue -Object $step -Name 'continueOnFailure' -DefaultValue $false)){'True'}else{'False'}
            $policy=Get-DynomaxExecutionPolicy -Step $step -FallbackTimeoutSeconds ([int](Get-DynomaxPropertyValue -Object $definition -Name 'timeoutSeconds' -DefaultValue 60))
            $retryOnCsv=ConvertTo-DynomaxRobotCellValue -Value (@($policy.RetryOn) -join ',')
            $sensitiveAction=$false
            foreach($input in @((Get-DynomaxPropertyValue -Object $definition -Name 'inputs' -DefaultValue @()))){
                $classification=[string](Get-DynomaxPropertyValue -Object $input -Name 'classification' -DefaultValue 'Normal')
                $secretFlag=[bool](Get-DynomaxPropertyValue -Object $input -Name 'secret' -DefaultValue $false)
                if($secretFlag -or $classification -in @('Secret','Sensitive')){$sensitiveAction=$true;break}
            }
            $sensitiveText=if($sensitiveAction){'True'}else{'False'}
            $slotKeyword=('Execute Dynomax Physical Slot {0:D6}' -f [int]$step.order)
            $lines.Add($slotKeyword)
            $scheduledCall=@(
                'Execute Dynomax Scheduled Slot',
                [string]$step.actionId,
                [string][int]$step.order,
                $stepId,
                $workflowNodeId,
                [string]$executionSlot,
                $outputSpecsB64,
                $cleanup,
                $continueOnFailure,
                $actionVersionId,
                $requestedRobotCell,
                $resolvedVersion,
                [string]$policy.WaitBeforeSeconds,
                [string]$policy.AttemptTimeoutSeconds,
                [string]$policy.MaximumAttempts,
                [string]$policy.RetryDelaySeconds,
                [string]$policy.Backoff,
                [string]$policy.MaximumRetryDelaySeconds,
                [string]$policy.OverallTimeoutSeconds,
                $retryOnCsv,
                [string]$policy.EvidencePolicy,
                [string]$policy.BrowserSessionRetryMode,
                $sensitiveText,
                [string]$definition.keyword
            )
            $lines.Add('    '+([string]::Join('    ',$scheduledCall)))
            $lines.Add('')
        }
    }

    else{
        foreach($step in $Steps){
            $definition=$actionDefinitions[[string][int]$step.order]
            $cleanup=if([bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)){'True'}else{'False'}
            $requestedVersion=Get-DynomaxPropertyValue -Object $step -Name 'DynomaxRequestedActionVersion' -DefaultValue $null
            $requestedText=if($null -eq $requestedVersion){''}else{[string]$requestedVersion}
            $requestedRobotCell=ConvertTo-DynomaxRobotCellValue -Value $requestedText
            $resolvedVersion=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxResolvedActionVersion' -DefaultValue '')
            $actionVersionId=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue '')
            if(-not $actionVersionId){throw "Action '$($step.actionId)' has no preflight action-version ID."}
            $stepId=[string](Get-DynomaxPropertyValue -Object $step -Name 'stepId' -DefaultValue ("step-{0}" -f $step.order))
            $workflowNodeId=[string](Get-DynomaxPropertyValue -Object $step -Name 'workflowNodeId' -DefaultValue $stepId)
            $executionSlot=[int](Get-DynomaxPropertyValue -Object $step -Name 'executionSlot' -DefaultValue 1)
            $outputSpecs=@((Get-DynomaxPropertyValue -Object $definition -Name 'outputs' -DefaultValue @())|ForEach-Object{[ordered]@{name=[string](Get-DynomaxPropertyValue -Object $_ -Name 'name' -DefaultValue '');classification=[string](Get-DynomaxPropertyValue -Object $_ -Name 'classification' -DefaultValue 'Normal');persistInResult=[bool](Get-DynomaxPropertyValue -Object $_ -Name 'persistInResult' -DefaultValue $true);sensitiveWhenInputsSensitive=@(Get-DynomaxPropertyValue -Object $_ -Name 'sensitiveWhenInputsSensitive' -DefaultValue @())}})
            $outputSpecsJson=ConvertTo-Json -InputObject $outputSpecs -Depth 10 -Compress
            $outputSpecsB64=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($outputSpecsJson))
            $name=('{0:D6} - {1}' -f [int]$step.order,[string]$step.actionId)
            $lines.Add($name)
            $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_METADATA_READY}    False")
            $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_ID}    $($step.actionId)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_STEP_ORDER}    $($step.order)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_STEP_ID}    $stepId")
            $lines.Add("    Set Test Variable    `${DYNOMAX_WORKFLOW_NODE_ID}    $workflowNodeId")
            $lines.Add("    Set Test Variable    `${DYNOMAX_EXECUTION_SLOT}    $executionSlot")
            $lines.Add("    Set Test Variable    `${DYNOMAX_OUTPUT_SPECS_B64}    $outputSpecsB64")
            $lines.Add("    Set Test Variable    `${DYNOMAX_IS_CLEANUP}    $cleanup")
            $continueOnFailure=if([bool](Get-DynomaxPropertyValue -Object $step -Name 'continueOnFailure' -DefaultValue $false)){'True'}else{'False'}
            $lines.Add("    Set Test Variable    `${DYNOMAX_CONTINUE_ON_FAILURE}    $continueOnFailure")
            $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_VERSION_ID}    $actionVersionId")
            $lines.Add("    Set Test Variable    `${DYNOMAX_REQUESTED_ACTION_VERSION}    $requestedRobotCell")
            $policy=Get-DynomaxExecutionPolicy -Step $step -FallbackTimeoutSeconds ([int](Get-DynomaxPropertyValue -Object $definition -Name 'timeoutSeconds' -DefaultValue 60))
            $retryOnCsv=ConvertTo-DynomaxRobotCellValue -Value (@($policy.RetryOn) -join ',')
            $sensitiveAction=$false
            foreach($input in @((Get-DynomaxPropertyValue -Object $definition -Name 'inputs' -DefaultValue @()))){
                $classification=[string](Get-DynomaxPropertyValue -Object $input -Name 'classification' -DefaultValue 'Normal')
                $secretFlag=[bool](Get-DynomaxPropertyValue -Object $input -Name 'secret' -DefaultValue $false)
                if($secretFlag -or $classification -in @('Secret','Sensitive')){$sensitiveAction=$true;break}
            }
            $sensitiveText=if($sensitiveAction){'True'}else{'False'}
            $lines.Add("    Set Test Variable    `${DYNOMAX_RESOLVED_ACTION_VERSION}    $resolvedVersion")
            $lines.Add("    Set Test Variable    `${DYNOMAX_WAIT_BEFORE_SECONDS}    $($policy.WaitBeforeSeconds)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_ATTEMPT_TIMEOUT_SECONDS}    $($policy.AttemptTimeoutSeconds)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_MAXIMUM_ATTEMPTS}    $($policy.MaximumAttempts)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_RETRY_DELAY_SECONDS}    $($policy.RetryDelaySeconds)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_BACKOFF}    $($policy.Backoff)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_MAXIMUM_RETRY_DELAY_SECONDS}    $($policy.MaximumRetryDelaySeconds)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_OVERALL_TIMEOUT_SECONDS}    $($policy.OverallTimeoutSeconds)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_RETRY_ON_CSV}    $retryOnCsv")
            $lines.Add("    Set Test Variable    `${DYNOMAX_ATTEMPT_EVIDENCE_POLICY}    $($policy.EvidencePolicy)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_BROWSER_SESSION_RETRY_MODE}    $($policy.BrowserSessionRetryMode)")
            $lines.Add("    Set Test Variable    `${DYNOMAX_SENSITIVE_ACTION}    $sensitiveText")
            $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_METADATA_READY}    True")
            if($cleanup -eq 'True'){
                $lines.Add("    `${cleanup_stop_requested}=    Get Variable Value    \`${DYNOMAX_CLEANUP_STOP_REQUESTED}    `${False}")
                $lines.Add("    IF    `${cleanup_stop_requested}")
                $lines.Add("        Skip    Cleanup stopped after the first failed Cleanup Action because continueOnFailure is false.")
                $lines.Add("    END")
            }
            if($controlFlowEnabled -and $cleanup -eq 'False'){
                # After terminal control flow is established, the remainder of a pre-unrolled Robot
                # suite is a bookkeeping concern only. Skip it locally without launching another
                # control-flow PowerShell process or per-slot persistence subprocess. Core bulk-fills
                # the missing physical ActionRun rows after the Robot block returns.
                $lines.Add("    IF    `${DYNOMAX_CONTROL_FLOW_TERMINAL}")
                $lines.Add("        Set Test Variable    `${DYNOMAX_ACTION_METADATA_READY}    False")
                $lines.Add("        Skip    Workflow control flow already reached a terminal state.")
                $lines.Add("    END")
                $lines.Add("    `${control_flow_decision}=    Should Run Dynomax Control Flow Action    $workflowNodeId")
                $lines.Add("    IF    '`${control_flow_decision}' == 'DEFER'")
                $lines.Add("        Set Test Variable    `${DYNOMAX_ACTION_METADATA_READY}    False")
                $lines.Add("        Skip    Action execution slot deferred by Workflow control flow.")
                $lines.Add("    END")
                $lines.Add("    IF    '`${control_flow_decision}' == 'SKIP_FINAL'")
                $lines.Add("        Skip    Action was not selected by Workflow control flow.")
                $lines.Add("    END")
            }
            $lines.Add("    `${continuation_decision}=    Get Dynomax Continuation Decision    `${DYNOMAX_CONTEXT_PATH}    $stepId")
            $lines.Add("    IF    '`${continuation_decision}' == 'BLOCKED'")
            $lines.Add("        Set Test Variable    `${DYNOMAX_ACTION_METADATA_READY}    False")
            $lines.Add("        Fail    Continuation is blocked at physical step '$stepId'. Inspect the immutable continuation plan for the safety reason.")
            $lines.Add("    END")
            $lines.Add("    IF    '`${continuation_decision}' == 'REUSE'")
            if($controlFlowEnabled -and $cleanup -eq 'False'){
                $lines.Add("        Advance Dynomax Control Flow After Reused Action    $workflowNodeId")
            }
            $lines.Add("        Set Test Variable    `${DYNOMAX_ACTION_METADATA_READY}    False")
            $lines.Add("        Pass Execution    Reused from the source Run; this Action did not execute.")
            $lines.Add("    END")
            $lines.Add("    Begin Dynomax Step Scope    `${DYNOMAX_CONTEXT_PATH}    $stepId    `${DYNOMAX_OUTPUT_SPECS_B64}")
            $lines.Add("    `${runtime_sensitive}=    Is Dynomax Active Step Sensitive    `${DYNOMAX_CONTEXT_PATH}    $stepId")
            $lines.Add("    IF    `${runtime_sensitive}")
            $lines.Add("        Set Test Variable    `${DYNOMAX_SENSITIVE_ACTION}    True")
            $lines.Add("    END")
            $lines.Add("    Mark Dynomax Action Running")
            $lines.Add("    TRY")
            $lines.Add("        Execute Dynomax Action With Policy    $($definition.keyword)    $cleanup")
            $lines.Add("    FINALLY")
            $lines.Add("        Complete Dynomax Step Scope    `${DYNOMAX_CONTEXT_PATH}    $stepId    $workflowNodeId    $executionSlot    $($step.actionId)    `${DYNOMAX_OUTPUT_SPECS_B64}")
            $lines.Add("    END")
            if($controlFlowEnabled -and $cleanup -eq 'False'){
                # Restore the shared output context before Condition/Fork/Loop evaluation so
                # step-local inputs cannot shadow an earlier output with the same context key.
                $lines.Add("    Advance Dynomax Control Flow After Action    $workflowNodeId")
            }
            $lines.Add('')
        }
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
        [bool]$StreamOutput=$true,[bool]$ShowCommand=$false,[int]$HeartbeatSeconds=15,[bool]$PreserveCleanupBrowserSession=$false
    )
    $suite=New-DynomaxRobotSuite -DynomaxRoot $DynomaxRoot -ProjectFolder $ProjectFolder -ProjectConfig $ProjectConfig -Workflow $Workflow -Steps $Steps -RunId $RunId -RunDirectory $RunDirectory -ContextPath $ContextPath -WorkflowDirectory $WorkflowDirectory -PowerShellPath $PowerShellPath -PreserveCleanupBrowserSession:$PreserveCleanupBrowserSession
    $resultDir=Ensure-DynomaxDirectory -Path (Join-Path $RunDirectory 'robot-result')
    $args=@('-B','-m','robot','--outputdir',$resultDir,'--output','output.xml','--log','log.html','--report','report.html',$suite)
    $heartbeat={param($label,$processId,$elapsedSeconds) Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Runtime.Heartbeat' -Message ("$label is still running; elapsed ${elapsedSeconds}s.") -Data ([ordered]@{process='Robot';processId=$processId;elapsedSeconds=$elapsedSeconds})}
    return Invoke-DynomaxProcess -FilePath $PythonPath -Arguments $args -WorkingDirectory $RunDirectory -TimeoutSeconds $TimeoutSeconds -ConsoleLogPath (Join-Path $RunDirectory 'robot-console.log') -Environment @{ 'PYTHONDONTWRITEBYTECODE'='1' } -StreamOutput:$StreamOutput -ShowCommand:$ShowCommand -HeartbeatSeconds $HeartbeatSeconds -DisplayName 'Robot workflow' -HeartbeatCallback $heartbeat
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
    $fingerprint=Assert-DynomaxActionExecutionSourceUnchanged -Step $Step -ProjectFolder $ProjectFolder -WorkflowDirectory $WorkflowDirectory
    $folder=[string]$fingerprint.Folder
    $definition=$fingerprint.Definition
    $entry=[string]$fingerprint.EntryPointPath
    $policy=Get-DynomaxExecutionPolicy -Step $Step -FallbackTimeoutSeconds ([int](Get-DynomaxPropertyValue -Object $definition -Name 'timeoutSeconds' -DefaultValue 60))
    $isSensitiveAction=$false
    foreach($input in @((Get-DynomaxPropertyValue -Object $definition -Name 'inputs' -DefaultValue @()))){
        $inputClassification=[string](Get-DynomaxPropertyValue -Object $input -Name 'classification' -DefaultValue 'Normal')
        $secretFlag=[bool](Get-DynomaxPropertyValue -Object $input -Name 'secret' -DefaultValue $false)
        if($secretFlag -or $inputClassification -in @('Secret','Sensitive')){$isSensitiveAction=$true;break}
    }
    $isCleanup=[bool](Get-DynomaxPropertyValue -Object $Step -Name 'cleanup' -DefaultValue $false)
    $actionVersionIdText=[string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxActionVersionId' -DefaultValue '')
    if(-not $actionVersionIdText){throw "Action '$($Step.actionId)' has no preflight action-version ID."}
    $actionVersionId=[Guid]$actionVersionIdText
    $stepId=[string](Get-DynomaxPropertyValue -Object $Step -Name 'stepId' -DefaultValue ("step-{0}" -f $Step.order))
    $actionVersion=[int](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxResolvedActionVersion' -DefaultValue (Get-DynomaxPropertyValue -Object $Step -Name 'actionVersion' -DefaultValue 0))
    # Clear declared output keys before this physical Action executes so a prior step's flat-context
    # value cannot be mistaken for this step's output. The active input scope retains the baseline.
    $prepareContext=Read-DynomaxJson -Path $ContextPath
    $activeOutputScope=Get-DynomaxPropertyValue -Object $prepareContext -Name 'activeStepInput' -DefaultValue $null
    if($null -eq $activeOutputScope){
        $activeOutputScope=[pscustomobject][ordered]@{stepId=$stepId;priorValues=[pscustomobject][ordered]@{};priorSecretFlags=[pscustomobject][ordered]@{}}
        $prepareContext | Add-Member -NotePropertyName 'activeStepInput' -NotePropertyValue $activeOutputScope
    }
    $priorOutputValues=[ordered]@{};$priorOutputSecretFlags=[ordered]@{};$priorOutputSensitiveFlags=[ordered]@{}
    $prepareSecretLookup=@{};foreach($key in @(Get-DynomaxPropertyValue -Object $prepareContext -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$prepareSecretLookup[[string]$key]=$true}}
    $prepareSensitiveLookup=@{};foreach($key in @(Get-DynomaxPropertyValue -Object $prepareContext -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$prepareSensitiveLookup[[string]$key]=$true}}
    foreach($outputDefinition in @((Get-DynomaxPropertyValue -Object $definition -Name 'outputs' -DefaultValue @()))){
        $outputName=[string](Get-DynomaxPropertyValue -Object $outputDefinition -Name 'name' -DefaultValue '')
        if([string]::IsNullOrWhiteSpace($outputName)){continue}
        $existingOutput=$prepareContext.values.PSObject.Properties[$outputName]
        $priorOutputValues[$outputName]=[ordered]@{exists=($null -ne $existingOutput);value=$(if($null -ne $existingOutput){$existingOutput.Value}else{$null})}
        $priorOutputSecretFlags[$outputName]=$prepareSecretLookup.ContainsKey($outputName)
        $priorOutputSensitiveFlags[$outputName]=$prepareSensitiveLookup.ContainsKey($outputName)
        $activePriorValues=Get-DynomaxPropertyValue -Object $activeOutputScope -Name 'priorValues' -DefaultValue $null
        $isAlsoInput=$null -ne $activePriorValues -and $null -ne $activePriorValues.PSObject.Properties[$outputName]
        if(-not $isAlsoInput){[void]$prepareContext.values.PSObject.Properties.Remove($outputName);[void]$prepareSecretLookup.Remove($outputName);[void]$prepareSensitiveLookup.Remove($outputName)}
    }
    $activeOutputScope | Add-Member -Force -NotePropertyName 'priorOutputValues' -NotePropertyValue ([pscustomobject]$priorOutputValues)
    $activeOutputScope | Add-Member -Force -NotePropertyName 'priorOutputSecretFlags' -NotePropertyValue ([pscustomobject]$priorOutputSecretFlags)
    $activeOutputScope | Add-Member -Force -NotePropertyName 'priorOutputSensitiveFlags' -NotePropertyValue ([pscustomobject]$priorOutputSensitiveFlags)
    $prepareContext.secretKeys=@($prepareSecretLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $prepareContext -Name 'sensitiveKeys' -Value @($prepareSensitiveLookup.Keys|Sort-Object)
    Write-DynomaxJson -Value $prepareContext -Path $ContextPath
    $startStream=if($isCleanup){'CleanupActionStarted'}else{'MainActionStarted'}
    $startEventId=Get-DynomaxControlFlowRunEventId -RunId $RunId -Stream $startStream -Sequence ([int]$Step.order)
    Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Runtime.ActionStarted' -Message ("Action '$($Step.actionId)' started.") -Data ([ordered]@{stepOrder=[int]$Step.order;stepId=$stepId;actionKey=[string]$Step.actionId;actionVersionId=$actionVersionId.ToString('D');isCleanup=$isCleanup}) -RunEventId $startEventId
    $overallWatch=[System.Diagnostics.Stopwatch]::StartNew()
    if($policy.WaitBeforeSeconds -gt 0){Start-Sleep -Seconds $policy.WaitBeforeSeconds}

    $finalResult=$null
    $lastProcess=$null
    for($attempt=1;$attempt -le $policy.MaximumAttempts;$attempt++){
        [void](Refresh-DynomaxRuntimeStepInputContext -ContextPath $ContextPath -StepId $stepId -AttemptNumber $attempt)
        $remaining=[Math]::Floor($policy.OverallTimeoutSeconds-$overallWatch.Elapsed.TotalSeconds)
        if($remaining -le 0){
            $finalResult=[pscustomobject]@{Status=$(if($isCleanup){'CLEANUP_FAILED'}else{'ERROR'});Message='Overall execution timeout expired before the next attempt could start.';OutputJson=$null}
            break
        }
        $attemptTimeout=[int][Math]::Max(1,[Math]::Min($policy.AttemptTimeoutSeconds,$remaining))
        $attemptDirectory=Ensure-DynomaxDirectory -Path (Join-Path $RunDirectory ("attempt-scratch\{0}\{1}" -f $Step.order,$attempt))
        $attemptOutputPath=Join-Path $attemptDirectory 'output.json'
        $attemptConsolePath=Join-Path $attemptDirectory 'console.log'
        $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-DynomaxRoot',$DynomaxRoot,'-RunId',[string]$RunId,'-StepOrder',[string]$Step.order,'-ContextPath',$ContextPath,'-OutputPath',$attemptOutputPath)
        $startedAt=[DateTime]::UtcNow
        $timedOut=$false
        $process=$null
        try{
            $heartbeat={param($label,$processId,$elapsedSeconds) Add-DynomaxRunEvent -SqlConfig $SqlConfig -RunId $RunId -EventLevel 'Info' -EventType 'Runtime.Heartbeat' -Message ("Action '$($Step.actionId)' attempt $attempt is still running; elapsed ${elapsedSeconds}s.") -Data ([ordered]@{process='PowerShellAction';stepOrder=[int]$Step.order;stepId=$stepId;actionKey=[string]$Step.actionId;attempt=$attempt;processId=$processId;elapsedSeconds=$elapsedSeconds})}
            $process=Invoke-DynomaxProcess -FilePath $PowerShellPath -Arguments $args -WorkingDirectory $folder -TimeoutSeconds $attemptTimeout -ConsoleLogPath $attemptConsolePath -StreamOutput:$StreamOutput -ShowCommand:$ShowCommand -HeartbeatSeconds $HeartbeatSeconds -DisplayName ("PowerShell action {0} attempt {1}" -f $Step.actionId,$attempt) -HeartbeatCallback $heartbeat
            $lastProcess=$process
            $attemptResult=Resolve-DynomaxExternalActionResult -ProcessResult $process -OutputPath $attemptOutputPath -IsCleanup:$isCleanup
        }
        catch{
            $timedOut=$_.Exception.Message -match '(?i)exceeded .* seconds|timeout'
            $attemptResult=[pscustomobject]@{Status=$(if($isCleanup){'CLEANUP_FAILED'}else{'ERROR'});Message=$_.Exception.Message;OutputJson=$null}
        }
        $endedAt=[DateTime]::UtcNow
        $declaredClassification=$null
        if($attemptOutputPath -and (Test-Path -LiteralPath $attemptOutputPath -PathType Leaf)){
            try{$outputObject=Read-DynomaxJson -Path $attemptOutputPath;$declaredClassification=[string](Get-DynomaxPropertyValue -Object $outputObject -Name 'failureClassification' -DefaultValue '')}catch{}
        }
        $classification=Get-DynomaxFailureClassification -Message $attemptResult.Message -TimedOut:$timedOut -DeclaredClassification $declaredClassification
        $canRetry=$attemptResult.Status -notin @('PASS','SKIPPED') -and $attempt -lt $policy.MaximumAttempts -and $classification -and @($policy.RetryOn) -contains $classification
        $delay=if($canRetry){Get-DynomaxRetryDelaySeconds -Policy $policy -CompletedAttemptNumber $attempt}else{0}
        if($canRetry -and ($overallWatch.Elapsed.TotalSeconds+$delay) -ge $policy.OverallTimeoutSeconds){$canRetry=$false;$delay=0}
        $isFinalAttempt=$attemptResult.Status -notin @('PASS','SKIPPED') -and -not $canRetry
        $retainEvidence=$attemptResult.Status -notin @('PASS','SKIPPED') -and ($policy.EvidencePolicy -eq 'EveryFailedAttempt' -or $isFinalAttempt)
        $attemptMessage=if($isSensitiveAction -and $attemptResult.Status -notin @('PASS','SKIPPED')){'Sensitive Action attempt failed; detailed message suppressed.'}else{$attemptResult.Message}
        $waitEvidence=if($attempt -eq 1){$policy.WaitBeforeSeconds}else{0}
        [void](Write-DynomaxExecutionAttempt -RunDirectory $RunDirectory -RunId $RunId -StepOrder ([int]$Step.order) -StepId $stepId -ActionKey ([string]$Step.actionId) -ActionVersion $actionVersion -ActionVersionId $actionVersionId -AttemptNumber $attempt -StartedAtUtc $startedAt -EndedAtUtc $endedAt -Status $attemptResult.Status -Message $attemptMessage -FailureClassification $classification -WaitBeforeExecutionSeconds $waitEvidence -DelayBeforeNextAttemptSeconds $delay -BrowserSessionDecision 'Reuse' -EvidencePolicy $policy.EvidencePolicy -EvidenceRetained:$retainEvidence -TimedOut:$timedOut -IsFinalAttempt:$isFinalAttempt -IsCleanup:$isCleanup)

        $finalOutputPath=Join-Path $RunDirectory ("action-{0}.json" -f $Step.order)
        $finalConsolePath=Join-Path $RunDirectory ("action-{0}.console.log" -f $Step.order)
        if($attemptResult.Status -in @('PASS','SKIPPED') -or $isFinalAttempt){
            if(Test-Path -LiteralPath $attemptOutputPath -PathType Leaf){Copy-Item -LiteralPath $attemptOutputPath -Destination $finalOutputPath -Force}
            if(-not $isSensitiveAction -and (Test-Path -LiteralPath $attemptConsolePath -PathType Leaf)){Copy-Item -LiteralPath $attemptConsolePath -Destination $finalConsolePath -Force}
        }elseif($policy.EvidencePolicy -eq 'EveryFailedAttempt'){
            $evidenceDirectory=Ensure-DynomaxDirectory -Path (Join-Path $RunDirectory ("attempt-evidence\{0}\{1}" -f $Step.order,$attempt))
            if(Test-Path -LiteralPath $attemptOutputPath -PathType Leaf){Copy-Item -LiteralPath $attemptOutputPath -Destination (Join-Path $evidenceDirectory 'output.json') -Force}
            if(Test-Path -LiteralPath $attemptConsolePath -PathType Leaf){Copy-Item -LiteralPath $attemptConsolePath -Destination (Join-Path $evidenceDirectory 'console.log') -Force}
        }
        if(Test-Path -LiteralPath $attemptDirectory){Remove-Item -LiteralPath $attemptDirectory -Recurse -Force -ErrorAction SilentlyContinue}

        $finalResult=$attemptResult
        if($attemptResult.Status -in @('PASS','SKIPPED') -or -not $canRetry){break}
        if($delay -gt 0){Start-Sleep -Seconds $delay}
    }
    $overallWatch.Stop()
    if($null -eq $finalResult){$finalResult=[pscustomobject]@{Status=$(if($isCleanup){'CLEANUP_FAILED'}else{'ERROR'});Message='Action execution ended without a final result.';OutputJson=$null}}
    $persistedMessage=if($isSensitiveAction -and $finalResult.Status -notin @('PASS','SKIPPED')){'Sensitive Action failed; detailed message suppressed.'}else{$finalResult.Message}
    $context=Read-DynomaxJson -Path $ContextPath
    $outputObject=$null
    if(-not [string]::IsNullOrWhiteSpace([string]$finalResult.OutputJson)){try{$outputObject=([string]$finalResult.OutputJson|ConvertFrom-Json)}catch{}}
    $workflowNodeId=[string](Get-DynomaxPropertyValue -Object $Step -Name 'workflowNodeId' -DefaultValue $stepId)
    $executionSlot=[int](Get-DynomaxPropertyValue -Object $Step -Name 'executionSlot' -DefaultValue 1)
    $outputDefinitions=@((Get-DynomaxPropertyValue -Object $definition -Name 'outputs' -DefaultValue @()))
    $poolStep=Set-DynomaxRunDataPoolStepOutputs -Context $context -StepId $stepId -WorkflowNodeId $workflowNodeId -ExecutionSlot $executionSlot -ActionKey ([string]$Step.actionId) -OutputDefinitions $outputDefinitions -OutputObject $outputObject
    $safePersisted=[ordered]@{}
    $poolOutputs=Get-DynomaxPropertyValue -Object $poolStep -Name 'outputs' -DefaultValue $null
    if($null -ne $poolOutputs){foreach($property in @($poolOutputs.PSObject.Properties)){
        $entry=$property.Value
        if([bool](Get-DynomaxPropertyValue -Object $entry -Name 'available' -DefaultValue $false) -and [string](Get-DynomaxPropertyValue -Object $entry -Name 'classification' -DefaultValue 'Normal') -eq 'Normal' -and [bool](Get-DynomaxPropertyValue -Object $entry -Name 'persistInResult' -DefaultValue $true)){
            $safePersisted[[string]$property.Name]=Get-DynomaxPropertyValue -Object $entry -Name 'value' -DefaultValue $null
        }
    }}
    $persistedOutput=if($safePersisted.Count -gt 0){$safePersisted|ConvertTo-Json -Depth 50 -Compress}else{$null}
    if($isSensitiveAction -and $finalResult.Status -notin @('PASS','SKIPPED')){$persistedOutput=$null}
    Write-DynomaxJson -Value $context -Path $ContextPath
    Add-DynomaxActionRun -SqlConfig $SqlConfig -RunId $RunId -StepOrder ([int]$Step.order) -ActionKey ([string]$Step.actionId) -ActionVersionId $actionVersionId -Status $finalResult.Status -Message $persistedMessage -OutputJson $persistedOutput -IsCleanup:$isCleanup
    return $lastProcess
}
