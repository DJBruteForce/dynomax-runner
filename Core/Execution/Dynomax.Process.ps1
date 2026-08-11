Set-StrictMode -Version Latest

function ConvertTo-DynomaxNativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Format-DynomaxElapsed {
    param([Parameter(Mandatory)][TimeSpan]$Elapsed)
    if ($Elapsed.TotalHours -ge 1) { return $Elapsed.ToString('hh\:mm\:ss') }
    return $Elapsed.ToString('mm\:ss')
}

function Invoke-DynomaxProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory,
        [hashtable]$Environment,
        [int]$TimeoutSeconds = 0,
        [string]$ConsoleLogPath,
        [switch]$StreamOutput,
        [switch]$ShowCommand,
        [int]$HeartbeatSeconds = 15,
        [string]$DisplayName,
        [scriptblock]$HeartbeatCallback
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-DynomaxNativeArgument ([string]$_) }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $false
    if ($WorkingDirectory) { $startInfo.WorkingDirectory = $WorkingDirectory }
    if ($Environment) {
        foreach ($key in $Environment.Keys) {
            $startInfo.EnvironmentVariables[[string]$key] = [string]$Environment[$key]
        }
    }

    $label = if ($DisplayName) { $DisplayName } else { [System.IO.Path]::GetFileName($FilePath) }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $stdoutBuilder = New-Object System.Text.StringBuilder
    $stderrBuilder = New-Object System.Text.StringBuilder
    $timedOut = $false

    try {
        if ($ShowCommand) {
            Write-Host ("[Dynomax] START {0}: {1} {2}" -f $label, $FilePath, $startInfo.Arguments) -ForegroundColor Cyan
        }
        else {
            Write-Host ("[Dynomax] START {0}" -f $label) -ForegroundColor Cyan
        }

        if (-not $process.Start()) { throw "Could not start process '$FilePath'." }
        Write-Host ("[Dynomax] PID {0}; timeout {1}" -f $process.Id, $(if ($TimeoutSeconds -gt 0) { "$TimeoutSeconds seconds" } else { 'disabled' })) -ForegroundColor DarkGray

        $stdoutDone = $false
        $stderrDone = $false
        $stdoutTask = $process.StandardOutput.ReadLineAsync()
        $stderrTask = $process.StandardError.ReadLineAsync()
        $lastHeartbeat = [DateTime]::UtcNow
        $timeoutKillAt = $null

        while (-not ($process.HasExited -and $stdoutDone -and $stderrDone)) {
            if (-not $stdoutDone -and $stdoutTask.IsCompleted) {
                $line = $stdoutTask.GetAwaiter().GetResult()
                if ($null -eq $line) {
                    $stdoutDone = $true
                }
                else {
                    [void]$stdoutBuilder.AppendLine($line)
                    if ($StreamOutput) { Write-Host ("[{0}] {1}" -f $label, $line) }
                    $stdoutTask = $process.StandardOutput.ReadLineAsync()
                }
            }

            if (-not $stderrDone -and $stderrTask.IsCompleted) {
                $line = $stderrTask.GetAwaiter().GetResult()
                if ($null -eq $line) {
                    $stderrDone = $true
                }
                else {
                    [void]$stderrBuilder.AppendLine($line)
                    if ($StreamOutput) { Write-Host ("[{0} stderr] {1}" -f $label, $line) -ForegroundColor Yellow }
                    $stderrTask = $process.StandardError.ReadLineAsync()
                }
            }

            if (-not $timedOut -and -not $process.HasExited -and $TimeoutSeconds -gt 0 -and $stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                $timedOut = $true
                Write-Host ("[Dynomax] TIMEOUT {0} after {1}; terminating PID {2}." -f $label, (Format-DynomaxElapsed $stopwatch.Elapsed), $process.Id) -ForegroundColor Red
                try { $process.Kill() } catch { }
                try { $process.WaitForExit() } catch { }
                $timeoutKillAt = [DateTime]::UtcNow
            }

            if ($timedOut -and $timeoutKillAt -and ([DateTime]::UtcNow - $timeoutKillAt).TotalSeconds -gt 5) {
                break
            }

            if ($HeartbeatSeconds -gt 0 -and ([DateTime]::UtcNow - $lastHeartbeat).TotalSeconds -ge $HeartbeatSeconds -and -not $process.HasExited) {
                if($StreamOutput){Write-Host ("[Dynomax] RUNNING {0}; PID {1}; elapsed {2}." -f $label, $process.Id, (Format-DynomaxElapsed $stopwatch.Elapsed)) -ForegroundColor DarkGray}
                if($null -ne $HeartbeatCallback){
                    try{& $HeartbeatCallback $label $process.Id ([int][Math]::Floor($stopwatch.Elapsed.TotalSeconds))}catch{Write-Warning ("Dynomax live heartbeat persistence failed: {0}" -f $_.Exception.Message)}
                }
                $lastHeartbeat = [DateTime]::UtcNow
            }

            Start-Sleep -Milliseconds 100
        }

        if (-not $process.HasExited) {
            try { $process.WaitForExit() } catch { }
        }

        $stopwatch.Stop()
        $exitCode = if ($timedOut) { -2 } else { $process.ExitCode }
        $standardOutput = $stdoutBuilder.ToString()
        $standardError = $stderrBuilder.ToString()

        $result = [pscustomobject]@{
            FilePath = $FilePath
            Arguments = $Arguments
            ProcessId = $process.Id
            ExitCode = $exitCode
            TimedOut = $timedOut
            Elapsed = $stopwatch.Elapsed
            StandardOutput = $standardOutput
            StandardError = $standardError
        }

        Write-Host ("[Dynomax] END {0}; exit {1}; elapsed {2}." -f $label, $result.ExitCode, (Format-DynomaxElapsed $result.Elapsed)) -ForegroundColor $(if ($result.ExitCode -eq 0) { 'Green' } else { 'Red' })

        if ($ConsoleLogPath) {
            $directory = Split-Path -Parent $ConsoleLogPath
            if ($directory) { [System.IO.Directory]::CreateDirectory($directory) | Out-Null }
            $combined = @(
                "COMMAND: $FilePath $($startInfo.Arguments)",
                "PROCESS ID: $($result.ProcessId)",
                "EXIT CODE: $($result.ExitCode)",
                "TIMED OUT: $($result.TimedOut)",
                "ELAPSED: $(Format-DynomaxElapsed $result.Elapsed)",
                '--- STDOUT ---',
                $result.StandardOutput,
                '--- STDERR ---',
                $result.StandardError
            ) -join [Environment]::NewLine
            [System.IO.File]::WriteAllText($ConsoleLogPath, $combined, (New-Object System.Text.UTF8Encoding($false)))
        }

        if ($timedOut) { throw "Process '$FilePath' exceeded $TimeoutSeconds seconds." }
        return $result
    }
    finally {
        if ($stopwatch.IsRunning) { $stopwatch.Stop() }
        $process.Dispose()
    }
}

function Resolve-DynomaxCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }
    return $null
}
