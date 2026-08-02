Set-StrictMode -Version Latest

function New-DynomaxExecutionPlanException {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Classification,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][string]$Message,
        [Guid]$ActionVersionId = [Guid]::Empty
    )

    $exception = New-Object System.InvalidOperationException($Message)
    $exception.Data['DynomaxClassification'] = $Classification
    $exception.Data['DynomaxStepOrder'] = $StepOrder
    $exception.Data['DynomaxActionKey'] = $ActionKey
    if ($ActionVersionId -ne [Guid]::Empty) {
        $exception.Data['DynomaxActionVersionId'] = [string]$ActionVersionId
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
        [Guid]$ActionVersionId = [Guid]::Empty
    )

    throw (New-DynomaxExecutionPlanException -Classification $Classification -StepOrder $StepOrder -ActionKey $ActionKey -Message $Message -ActionVersionId $ActionVersionId)
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
    return [pscustomobject]@{
        Folder = $ActionJsonFile.Directory.FullName
        SourceLocation = $SourceLocation
        Definition = $definition
        DefinitionPath = $ActionJsonFile.FullName
        EntryPointPath = $entryPointPath
        DefinitionHash = Get-DynomaxTextSha256 -Text $canonical
        DefinitionFileSha256 = Get-DynomaxSha256 -Path $ActionJsonFile.FullName
        ImplementationHash = Get-DynomaxSha256 -Path $entryPointPath
    }
}

function Get-DynomaxActionSourceCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectFolder,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][int]$StepOrder,
        [string]$WorkflowDirectory
    )

    $candidates = New-Object System.Collections.Generic.List[object]
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
                $message = "Action source '$($file.FullName)' could not be fingerprinted: $($_.Exception.Message)"
                Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $StepOrder -ActionKey $ActionKey -Message $message
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
        $candidates = @(Get-DynomaxActionSourceCandidates -ProjectFolder $ProjectFolder -ActionKey $actionKey -StepOrder $stepOrder -WorkflowDirectory $WorkflowDirectory)
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
                Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Version-pinned workflows are fail-fast in Dynomax Core 1.0.9. Step '$key' cannot set continueOnFailure=true."
            }

            if ($engine -notin @('RobotBrowser','PowerShell')) {
                Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Action '$key' uses unsupported engine '$engine'."
            }
            if ($engine -eq 'RobotBrowser') {
                if ($session -notin @('RequiresNewBrowser','RequiresExistingBrowser','RequiresNewOrExistingBrowser')) {
                    Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "RobotBrowser action '$key' has unsupported session behavior '$session'."
                }
                if ($robotVersionByActionKey.ContainsKey($key) -and [string]$robotVersionByActionKey[$key] -ne [string]$versionId) {
                    Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "The $($section.Name) Robot block requests more than one version of action '$key'. Core 1.0.9 cannot load two resource versions with the same Robot keyword into one shared browser suite."
                }
                $robotVersionByActionKey[$key] = [string]$versionId
                if (-not $insideRobotBlock) {
                    $robotBlockCount++
                    if ($robotBlockCount -gt 1) {
                        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "The $($section.Name) plan contains more than one Robot browser block. Dynomax Core 1.0.9 supports one contiguous Robot block per normal or cleanup section."
                    }
                    if ($session -eq 'RequiresExistingBrowser') {
                        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $order -ActionKey $key -ActionVersionId $versionId -Message "Action '$key' requires an existing browser, but it starts the independent $($section.Name) Robot block."
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
        $fingerprint=Assert-DynomaxActionExecutionSourceUnchanged -Step $step -ProjectFolder $ProjectFolder -WorkflowDirectory $WorkflowDirectory
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
        $definition=$actionDefinitions[[string][int]$step.order]
        $cleanup=if([bool](Get-DynomaxPropertyValue -Object $step -Name 'cleanup' -DefaultValue $false)){'True'}else{'False'}
        $requestedVersion=Get-DynomaxPropertyValue -Object $step -Name 'DynomaxRequestedActionVersion' -DefaultValue $null
        $requestedText=if($null -eq $requestedVersion){''}else{[string]$requestedVersion}
        $resolvedVersion=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxResolvedActionVersion' -DefaultValue '')
        $actionVersionId=[string](Get-DynomaxPropertyValue -Object $step -Name 'DynomaxActionVersionId' -DefaultValue '')
        if(-not $actionVersionId){throw "Action '$($step.actionId)' has no preflight action-version ID."}
        $name=('{0:D6} - {1}' -f [int]$step.order,[string]$step.actionId)
        $lines.Add($name)
        $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_ID}    $($step.actionId)")
        $lines.Add("    Set Test Variable    `${DYNOMAX_STEP_ORDER}    $($step.order)")
        $lines.Add("    Set Test Variable    `${DYNOMAX_IS_CLEANUP}    $cleanup")
        $lines.Add("    Set Test Variable    `${DYNOMAX_ACTION_VERSION_ID}    $actionVersionId")
        $lines.Add("    Set Test Variable    `${DYNOMAX_REQUESTED_ACTION_VERSION}    $requestedText")
        $lines.Add("    Set Test Variable    `${DYNOMAX_RESOLVED_ACTION_VERSION}    $resolvedVersion")
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
    $fingerprint=Assert-DynomaxActionExecutionSourceUnchanged -Step $Step -ProjectFolder $ProjectFolder -WorkflowDirectory $WorkflowDirectory
    $folder=[string]$fingerprint.Folder
    $definition=$fingerprint.Definition
    $entry=[string]$fingerprint.EntryPointPath
    $outputPath=Join-Path $RunDirectory ("action-{0}.json" -f $Step.order)
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',$entry,'-DynomaxRoot',$DynomaxRoot,'-RunId',[string]$RunId,'-StepOrder',[string]$Step.order,'-ContextPath',$ContextPath,'-OutputPath',$outputPath)
    $process=Invoke-DynomaxProcess -FilePath $PowerShellPath -Arguments $args -WorkingDirectory $folder -TimeoutSeconds ([int](Get-DynomaxPropertyValue -Object $definition -Name 'timeoutSeconds' -DefaultValue 0)) -ConsoleLogPath (Join-Path $RunDirectory ("action-{0}.console.log" -f $Step.order)) -StreamOutput:$StreamOutput -ShowCommand:$ShowCommand -HeartbeatSeconds $HeartbeatSeconds -DisplayName ("PowerShell action {0}" -f $Step.actionId)
    $isCleanup=[bool](Get-DynomaxPropertyValue -Object $Step -Name 'cleanup' -DefaultValue $false)
    $actionResult=Resolve-DynomaxExternalActionResult -ProcessResult $process -OutputPath $outputPath -IsCleanup:$isCleanup
    $actionVersionIdText=[string](Get-DynomaxPropertyValue -Object $Step -Name 'DynomaxActionVersionId' -DefaultValue '')
    if(-not $actionVersionIdText){throw "Action '$($Step.actionId)' has no preflight action-version ID."}
    Add-DynomaxActionRun -SqlConfig $SqlConfig -RunId $RunId -StepOrder ([int]$Step.order) -ActionKey ([string]$Step.actionId) -ActionVersionId ([Guid]$actionVersionIdText) -Status $actionResult.Status -Message $actionResult.Message -OutputJson $actionResult.OutputJson -IsCleanup:$isCleanup
    return $process
}
