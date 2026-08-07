Set-StrictMode -Version Latest

function Get-DynomaxExecutionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Step,
        [int]$FallbackTimeoutSeconds = 60
    )

    $source = Get-DynomaxPropertyValue -Object $Step -Name 'executionPolicy' -DefaultValue $null
    if ($null -eq $source) {
        return [pscustomobject]@{
            WaitBeforeSeconds = 0
            AttemptTimeoutSeconds = [Math]::Max(1,$FallbackTimeoutSeconds)
            MaximumAttempts = 1
            RetryDelaySeconds = 0
            Backoff = 'Fixed'
            MaximumRetryDelaySeconds = 0
            OverallTimeoutSeconds = [Math]::Max(1,$FallbackTimeoutSeconds)
            RetryOn = @()
            EvidencePolicy = 'FinalFailureOnly'
            BrowserSessionRetryMode = 'Reuse'
        }
    }

    $policy = [pscustomobject]@{
        WaitBeforeSeconds = [int](Get-DynomaxPropertyValue -Object $source -Name 'waitBeforeSeconds' -DefaultValue 0)
        AttemptTimeoutSeconds = [int](Get-DynomaxPropertyValue -Object $source -Name 'attemptTimeoutSeconds' -DefaultValue $FallbackTimeoutSeconds)
        MaximumAttempts = [int](Get-DynomaxPropertyValue -Object $source -Name 'maximumAttempts' -DefaultValue 1)
        RetryDelaySeconds = [int](Get-DynomaxPropertyValue -Object $source -Name 'retryDelaySeconds' -DefaultValue 0)
        Backoff = [string](Get-DynomaxPropertyValue -Object $source -Name 'backoff' -DefaultValue 'Fixed')
        MaximumRetryDelaySeconds = [int](Get-DynomaxPropertyValue -Object $source -Name 'maximumRetryDelaySeconds' -DefaultValue 0)
        OverallTimeoutSeconds = [int](Get-DynomaxPropertyValue -Object $source -Name 'overallTimeoutSeconds' -DefaultValue $FallbackTimeoutSeconds)
        RetryOn = @((Get-DynomaxPropertyValue -Object $source -Name 'retryOn' -DefaultValue @()) | ForEach-Object { [string]$_ })
        EvidencePolicy = [string](Get-DynomaxPropertyValue -Object $source -Name 'evidencePolicy' -DefaultValue 'FinalFailureOnly')
        BrowserSessionRetryMode = [string](Get-DynomaxPropertyValue -Object $source -Name 'browserSessionRetryMode' -DefaultValue 'Reuse')
    }

    if ($policy.WaitBeforeSeconds -lt 0 -or $policy.WaitBeforeSeconds -gt 86400) { throw 'waitBeforeSeconds is outside the supported range.' }
    if ($policy.AttemptTimeoutSeconds -lt 1 -or $policy.AttemptTimeoutSeconds -gt 86400) { throw 'attemptTimeoutSeconds is outside the supported range.' }
    if ($policy.MaximumAttempts -lt 1 -or $policy.MaximumAttempts -gt 100) { throw 'maximumAttempts is outside the supported range.' }
    if ($policy.RetryDelaySeconds -lt 0 -or $policy.RetryDelaySeconds -gt 86400) { throw 'retryDelaySeconds is outside the supported range.' }
    if ($policy.MaximumRetryDelaySeconds -lt 0 -or $policy.MaximumRetryDelaySeconds -gt 86400) { throw 'maximumRetryDelaySeconds is outside the supported range.' }
    if ($policy.OverallTimeoutSeconds -lt ($policy.WaitBeforeSeconds + $policy.AttemptTimeoutSeconds) -or $policy.OverallTimeoutSeconds -gt 604800) { throw 'overallTimeoutSeconds must allow the configured wait and at least one full attempt.' }
    if ($policy.Backoff -notin @('Fixed','Linear','Exponential')) { throw "Unsupported backoff mode '$($policy.Backoff)'." }
    if ($policy.EvidencePolicy -notin @('FinalFailureOnly','EveryFailedAttempt')) { throw "Unsupported evidence policy '$($policy.EvidencePolicy)'." }
    if ($policy.BrowserSessionRetryMode -notin @('Reuse','Reset')) { throw "Unsupported browser session retry mode '$($policy.BrowserSessionRetryMode)'." }
    if ($policy.MaximumAttempts -gt 1 -and $policy.RetryOn.Count -eq 0) { throw 'Retry-enabled execution requires retryOn classifications.' }
    if ($policy.MaximumAttempts -eq 1 -and $policy.RetryOn.Count -gt 0) { throw 'retryOn classifications require maximumAttempts greater than one.' }
    if ($policy.MaximumAttempts -gt 1 -and $policy.MaximumRetryDelaySeconds -lt $policy.RetryDelaySeconds) { throw 'maximumRetryDelaySeconds cannot be lower than retryDelaySeconds.' }
    return $policy
}

function Get-DynomaxRetryDelaySeconds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Policy,
        [Parameter(Mandatory)][int]$CompletedAttemptNumber
    )

    if ($CompletedAttemptNumber -lt 1 -or $Policy.RetryDelaySeconds -le 0) { return 0 }
    [double]$delay = [double]$Policy.RetryDelaySeconds
    switch ([string]$Policy.Backoff) {
        'Linear' { $delay = $delay * $CompletedAttemptNumber }
        'Exponential' { $delay = $delay * [Math]::Pow(2,[Math]::Max(0,$CompletedAttemptNumber - 1)) }
        default { }
    }
    if ($Policy.MaximumRetryDelaySeconds -gt 0) {
        $delay = [Math]::Min($delay,[double]$Policy.MaximumRetryDelaySeconds)
    }
    return [int][Math]::Ceiling($delay)
}

function Get-DynomaxFailureClassification {
    [CmdletBinding()]
    param(
        [string]$Message,
        [bool]$TimedOut = $false,
        [string]$DeclaredClassification
    )

    $supported = @(
        'ConnectionRefused','DnsUnavailable','NavigationTimeout','OperationTimeout','ConnectionReset',
        'Http408','Http429','Http502','Http503','Http504','ConfiguredTransientResult'
    )
    if ($DeclaredClassification -and $supported -contains $DeclaredClassification) { return $DeclaredClassification }
    if ($TimedOut) {
        if ($Message -match '(?i)page\.goto|navigation') { return 'NavigationTimeout' }
        return 'OperationTimeout'
    }
    $text = [string]$Message
    if ($text -match '(?i)ERR_CONNECTION_REFUSED|connection refused|actively refused') { return 'ConnectionRefused' }
    if ($text -match '(?i)ERR_NAME_NOT_RESOLVED|DNS|name or service not known|host.*not found') { return 'DnsUnavailable' }
    if ($text -match '(?i)ERR_CONNECTION_RESET|connection reset|forcibly closed') { return 'ConnectionReset' }
    if ($text -match '(?i)HTTP(?: status)?\s*408|\b408\b.*request timeout') { return 'Http408' }
    if ($text -match '(?i)HTTP(?: status)?\s*429|\b429\b.*too many requests') { return 'Http429' }
    if ($text -match '(?i)HTTP(?: status)?\s*502|\b502\b.*bad gateway') { return 'Http502' }
    if ($text -match '(?i)HTTP(?: status)?\s*503|\b503\b.*service unavailable') { return 'Http503' }
    if ($text -match '(?i)HTTP(?: status)?\s*504|\b504\b.*gateway timeout') { return 'Http504' }
    if ($text -match '(?i)timeout|timed out|exceeded .* seconds') {
        if ($text -match '(?i)page\.goto|navigation') { return 'NavigationTimeout' }
        return 'OperationTimeout'
    }
    return $null
}

function Write-DynomaxExecutionAttempt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunDirectory,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][int]$StepOrder,
        [Parameter(Mandatory)][string]$StepId,
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][int]$ActionVersion,
        [Parameter(Mandatory)][Guid]$ActionVersionId,
        [Parameter(Mandatory)][int]$AttemptNumber,
        [Parameter(Mandatory)][datetime]$StartedAtUtc,
        [Parameter(Mandatory)][datetime]$EndedAtUtc,
        [Parameter(Mandatory)][string]$Status,
        [string]$Message,
        [string]$FailureClassification,
        [int]$WaitBeforeExecutionSeconds = 0,
        [int]$DelayBeforeNextAttemptSeconds = 0,
        [string]$BrowserSessionDecision = 'Reuse',
        [string]$EvidencePolicy = 'FinalFailureOnly',
        [bool]$EvidenceRetained = $false,
        [bool]$IsFinalAttempt = $false,
        [bool]$IsCleanup = $false
    )

    $path = Join-Path $RunDirectory 'execution-attempts.jsonl'
    $record = [ordered]@{
        schemaVersion = 1
        runId = [string]$RunId
        stepOrder = $StepOrder
        stepId = $StepId
        actionId = $ActionKey
        actionVersion = $ActionVersion
        actionVersionId = [string]$ActionVersionId
        attemptNumber = $AttemptNumber
        startedAtUtc = $StartedAtUtc.ToUniversalTime().ToString('o')
        endedAtUtc = $EndedAtUtc.ToUniversalTime().ToString('o')
        elapsedMilliseconds = [long]($EndedAtUtc - $StartedAtUtc).TotalMilliseconds
        status = $Status
        failureClassification = $(if ($FailureClassification) { $FailureClassification } else { $null })
        waitBeforeExecutionSeconds = $WaitBeforeExecutionSeconds
        delayBeforeNextAttemptSeconds = $DelayBeforeNextAttemptSeconds
        browserSessionDecision = $BrowserSessionDecision
        evidencePolicy = $EvidencePolicy
        evidenceRetained = $EvidenceRetained
        finalAttempt = $IsFinalAttempt
        cleanup = $IsCleanup
        message = $(if ($Message) { if ($Message.Length -gt 4000) { $Message.Substring(0,4000) } else { $Message } } else { $null })
    }
    $json = $record | ConvertTo-Json -Depth 20 -Compress
    $directory = Split-Path -Parent $path
    if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
    [System.IO.File]::AppendAllText($path,$json + [Environment]::NewLine,(New-Object System.Text.UTF8Encoding($false)))
    return [pscustomobject]$record
}

function Get-DynomaxExecutionAttemptSummary {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RunDirectory)

    $path = Join-Path $RunDirectory 'execution-attempts.jsonl'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return [ordered]@{ totalAttempts=0; actionsRetried=0; actionsRecoveredAfterRetry=0; actionsWithExhaustedRetries=0 }
    }
    $records = @(
        Get-Content -LiteralPath $path -Encoding UTF8 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_ | ConvertFrom-Json }
    )
    $groups = @($records | Group-Object { "{0}|{1}" -f $_.stepId,$_.actionId })
    return [ordered]@{
        totalAttempts = $records.Count
        actionsRetried = @($groups | Where-Object { $_.Count -gt 1 }).Count
        actionsRecoveredAfterRetry = @($groups | Where-Object { $_.Count -gt 1 -and @($_.Group | Where-Object { $_.status -eq 'PASS' }).Count -gt 0 }).Count
        actionsWithExhaustedRetries = @($groups | Where-Object { $_.Count -gt 1 -and @($_.Group | Where-Object { $_.finalAttempt -and $_.status -ne 'PASS' }).Count -gt 0 }).Count
    }
}

function Assert-DynomaxStepExecutionPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Step,
        [Parameter(Mandatory)]$ActionDefinition,
        [Parameter(Mandatory)][Guid]$ActionVersionId
    )

    $stepOrder = [int]$Step.order
    $actionKey = [string]$Step.actionId
    $actionTimeout = [int](Get-DynomaxPropertyValue -Object $ActionDefinition -Name 'timeoutSeconds' -DefaultValue 60)
    $policy = Get-DynomaxExecutionPolicy -Step $Step -FallbackTimeoutSeconds $actionTimeout
    $contract = Get-DynomaxPropertyValue -Object $ActionDefinition -Name 'executionPolicy' -DefaultValue $null
    $limits = if ($contract) { Get-DynomaxPropertyValue -Object $contract -Name 'limits' -DefaultValue $null } else { $null }

    $maximumWait = if ($limits) { [int](Get-DynomaxPropertyValue -Object $limits -Name 'maximumWaitBeforeSeconds' -DefaultValue 3600) } else { 3600 }
    $maximumAttemptTimeout = if ($limits) { [int](Get-DynomaxPropertyValue -Object $limits -Name 'maximumAttemptTimeoutSeconds' -DefaultValue $actionTimeout) } else { $actionTimeout }
    $maximumAttempts = if ($limits) { [int](Get-DynomaxPropertyValue -Object $limits -Name 'maximumAttempts' -DefaultValue 1) } else { 1 }
    $maximumRetryDelay = if ($limits) { [int](Get-DynomaxPropertyValue -Object $limits -Name 'maximumRetryDelaySeconds' -DefaultValue 0) } else { 0 }
    $maximumOverallTimeout = if ($limits) { [int](Get-DynomaxPropertyValue -Object $limits -Name 'maximumOverallTimeoutSeconds' -DefaultValue $actionTimeout) } else { $actionTimeout }
    $allowedBackoff = if ($limits) { @((Get-DynomaxPropertyValue -Object $limits -Name 'allowedBackoffModes' -DefaultValue @('Fixed')) | ForEach-Object { [string]$_ }) } else { @('Fixed') }
    $allowedRetry = if ($limits) { @((Get-DynomaxPropertyValue -Object $limits -Name 'allowedRetryClassifications' -DefaultValue @()) | ForEach-Object { [string]$_ }) } else { @() }
    $allowedEvidence = if ($limits) { @((Get-DynomaxPropertyValue -Object $limits -Name 'allowedEvidencePolicies' -DefaultValue @('FinalFailureOnly')) | ForEach-Object { [string]$_ }) } else { @('FinalFailureOnly') }
    $allowedSession = if ($limits) { @((Get-DynomaxPropertyValue -Object $limits -Name 'allowedBrowserSessionRetryModes' -DefaultValue @('Reuse')) | ForEach-Object { [string]$_ }) } else { @('Reuse') }

    $problems = New-Object System.Collections.Generic.List[string]
    if ($policy.WaitBeforeSeconds -gt $maximumWait) { $problems.Add('waitBeforeSeconds exceeds the Action limit.') }
    if ($policy.AttemptTimeoutSeconds -gt $maximumAttemptTimeout) { $problems.Add('attemptTimeoutSeconds exceeds the Action limit.') }
    if ($policy.MaximumAttempts -gt $maximumAttempts) { $problems.Add('maximumAttempts exceeds the Action limit.') }
    if ($policy.MaximumRetryDelaySeconds -gt $maximumRetryDelay) { $problems.Add('maximumRetryDelaySeconds exceeds the Action limit.') }
    if ($policy.OverallTimeoutSeconds -gt $maximumOverallTimeout) { $problems.Add('overallTimeoutSeconds exceeds the Action limit.') }
    if ($allowedBackoff -notcontains $policy.Backoff) { $problems.Add("Backoff '$($policy.Backoff)' is not allowed by the Action version.") }
    if ($allowedEvidence -notcontains $policy.EvidencePolicy) { $problems.Add("Evidence policy '$($policy.EvidencePolicy)' is not allowed by the Action version.") }
    if ($allowedSession -notcontains $policy.BrowserSessionRetryMode) { $problems.Add("Browser retry mode '$($policy.BrowserSessionRetryMode)' is not allowed by the Action version.") }
    foreach ($classification in @($policy.RetryOn)) {
        if ($allowedRetry -notcontains ([string]$classification)) { $problems.Add("Retry classification '$classification' is not allowed by the Action version.") }
    }

    $isReplaySafe = [bool](Get-DynomaxPropertyValue -Object $ActionDefinition -Name 'isReplaySafe' -DefaultValue $false)
    if ($policy.MaximumAttempts -gt 1 -and -not $isReplaySafe) { $problems.Add('Automatic retry requires an immutable Action version marked replay-safe.') }

    $hasSensitiveInputs = $false
    foreach ($input in @((Get-DynomaxPropertyValue -Object $ActionDefinition -Name 'inputs' -DefaultValue @()))) {
        $classification = [string](Get-DynomaxPropertyValue -Object $input -Name 'classification' -DefaultValue 'Normal')
        $secretFlag = [bool](Get-DynomaxPropertyValue -Object $input -Name 'secret' -DefaultValue $false)
        if ($secretFlag -or $classification -in @('Secret','Sensitive')) { $hasSensitiveInputs = $true; break }
    }
    if ($hasSensitiveInputs -and $policy.EvidencePolicy -eq 'EveryFailedAttempt') { $problems.Add('Actions with secret or sensitive inputs may only retain final-failure attempt evidence.') }

    $sessionBehavior = [string](Get-DynomaxPropertyValue -Object $ActionDefinition -Name 'sessionBehavior' -DefaultValue 'DoesNotUseBrowser')
    if ($policy.BrowserSessionRetryMode -eq 'Reset' -and $sessionBehavior -eq 'RequiresExistingBrowser') {
        $problems.Add('Browser session reset cannot be used by an Action that requires an existing browser.')
    }
    if ($policy.BrowserSessionRetryMode -eq 'Reset' -and [string](Get-DynomaxPropertyValue -Object $ActionDefinition -Name 'engine' -DefaultValue '') -ne 'RobotBrowser') {
        $problems.Add('Browser session reset is only valid for Robot Browser Actions.')
    }

    if ($problems.Count -gt 0) {
        Throw-DynomaxExecutionPlanIssue -Classification 'TEST_INVALID' -StepOrder $stepOrder -ActionKey $actionKey -ActionVersionId $ActionVersionId -Message ($problems -join ' ')
    }
    return $policy
}
