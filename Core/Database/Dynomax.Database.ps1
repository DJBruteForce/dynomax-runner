Set-StrictMode -Version Latest

function New-DynomaxConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [string]$DatabaseOverride
    )

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = [string]$SqlConfig.host
    $builder['Initial Catalog'] = $(if ($DatabaseOverride) { $DatabaseOverride } else { [string]$SqlConfig.database })
    $mode = [string]$SqlConfig.authenticationMode
    if ($mode -eq 'Windows') {
        $builder['Integrated Security'] = $true
    }
    elseif ($mode -eq 'Sql') {
        $username = if ($SqlConfig.usernameEnvironmentVariable) { [Environment]::GetEnvironmentVariable([string]$SqlConfig.usernameEnvironmentVariable) } else { [string]$SqlConfig.username }
        $password = if ($SqlConfig.passwordEnvironmentVariable) { [Environment]::GetEnvironmentVariable([string]$SqlConfig.passwordEnvironmentVariable) } else { [string]$SqlConfig.password }
        if ([string]::IsNullOrWhiteSpace($username)) { throw 'SQL username was not supplied.' }
        $builder['User ID'] = $username
        $builder['Password'] = $password
    }
    else { throw "Unsupported SQL authentication mode '$mode'." }

    if ($null -ne $SqlConfig.encrypt) { $builder['Encrypt'] = [bool]$SqlConfig.encrypt }
    if ($null -ne $SqlConfig.trustServerCertificate) { $builder['TrustServerCertificate'] = [bool]$SqlConfig.trustServerCertificate }
    if ($SqlConfig.connectionTimeoutSeconds) { $builder['Connect Timeout'] = [int]$SqlConfig.connectionTimeoutSeconds }
    $builder['Application Name'] = 'Dynomax'
    return $builder.ConnectionString
}

function Open-DynomaxConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [string]$DatabaseOverride
    )
    $connection = New-Object System.Data.SqlClient.SqlConnection (New-DynomaxConnectionString -SqlConfig $SqlConfig -DatabaseOverride $DatabaseOverride)
    $connection.Open()
    return $connection
}

function Add-DynomaxSqlParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlCommand]$Command,
        [hashtable]$Parameters
    )

    if (-not $Parameters) { return }

    foreach ($name in $Parameters.Keys) {
        $parameterName = [string]$name
        $value = $Parameters[$name]
        $parameter = $null

        if ($null -eq $value -or $value -is [DBNull]) {
            $parameter = $Command.Parameters.AddWithValue($parameterName, [DBNull]::Value)
            continue
        }

        if ($value -is [byte[]]) {
            $parameter = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::VarBinary, -1)
            $parameter.Value = [byte[]]$value
            continue
        }

        if ($value -is [Guid]) {
            $parameter = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::UniqueIdentifier)
            $parameter.Value = [Guid]$value
            continue
        }

        if ($value -is [DateTime]) {
            $parameter = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::DateTime2)
            $parameter.Value = [DateTime]$value
            continue
        }

        if ($value -is [bool]) {
            $parameter = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Bit)
            $parameter.Value = [bool]$value
            continue
        }

        if ($value -is [int]) {
            $parameter = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::Int)
            $parameter.Value = [int]$value
            continue
        }

        if ($value -is [long]) {
            $parameter = $Command.Parameters.Add($parameterName, [System.Data.SqlDbType]::BigInt)
            $parameter.Value = [long]$value
            continue
        }

        # Do not wrap the value in $(). PowerShell enumerates byte arrays inside
        # subexpressions and changes System.Byte[] into System.Object[].
        $parameter = $Command.Parameters.AddWithValue($parameterName, [object]$value)
    }
}

function Invoke-DynomaxSqlNonQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][string]$CommandText,
        [hashtable]$Parameters,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [int]$CommandTimeoutSeconds = 120
    )
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $CommandText
        $command.CommandTimeout = $CommandTimeoutSeconds
        if ($Transaction) { $command.Transaction = $Transaction }
        Add-DynomaxSqlParameters -Command $command -Parameters $Parameters
        return $command.ExecuteNonQuery()
    }
    finally { $command.Dispose() }
}

function Invoke-DynomaxSqlScalar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][string]$CommandText,
        [hashtable]$Parameters,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [int]$CommandTimeoutSeconds = 120
    )
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $CommandText
        $command.CommandTimeout = $CommandTimeoutSeconds
        if ($Transaction) { $command.Transaction = $Transaction }
        Add-DynomaxSqlParameters -Command $command -Parameters $Parameters
        return $command.ExecuteScalar()
    }
    finally { $command.Dispose() }
}

function Invoke-DynomaxSqlRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory)][string]$CommandText,
        [hashtable]$Parameters,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [int]$CommandTimeoutSeconds = 120
    )
    $command = $Connection.CreateCommand()
    try {
        $command.CommandText = $CommandText
        $command.CommandTimeout = $CommandTimeoutSeconds
        if ($Transaction) { $command.Transaction = $Transaction }
        Add-DynomaxSqlParameters -Command $command -Parameters $Parameters
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $table = New-Object System.Data.DataTable
        [void]$adapter.Fill($table)
        return ,$table
    }
    finally { $command.Dispose() }
}

function Split-DynomaxSqlBatches {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SqlText)
    return [regex]::Split($SqlText, '(?im)^\s*GO\s*(?:--.*)?$') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function Test-DynomaxDatabaseConnection {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$SqlConfig, [string]$DatabaseOverride)
    $connection = $null
    try {
        $connection = Open-DynomaxConnection -SqlConfig $SqlConfig -DatabaseOverride $DatabaseOverride
        $value = Invoke-DynomaxSqlScalar -Connection $connection -CommandText 'SELECT 1;'
        return ([int]$value -eq 1)
    }
    finally { if ($connection) { $connection.Dispose() } }
}


function Test-DynomaxBinarySqlParameter {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection)

    [byte[]]$payload = [byte[]](0, 1, 2, 3, 127, 128, 254, 255)
    $length = Invoke-DynomaxSqlScalar -Connection $Connection -CommandText 'SELECT DATALENGTH(@Payload);' -Parameters @{ '@Payload' = $payload }
    return ([int]$length -eq $payload.Length)
}

function Add-DynomaxRunEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][string]$EventLevel,
        [Parameter(Mandatory)][string]$EventType,
        [Parameter(Mandatory)][string]$Message,
        $Data = $null,
        [Guid]$RunEventId = [Guid]::Empty,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    if ([string]::IsNullOrWhiteSpace($EventLevel)) { throw 'Run event level is required.' }
    if ([string]::IsNullOrWhiteSpace($EventType)) { throw 'Run event type is required.' }
    if ([string]::IsNullOrWhiteSpace($Message)) { throw 'Run event message is required.' }

    $dataJson = if ($null -eq $Data) { $null } else { $Data | ConvertTo-Json -Depth 12 -Compress }
    if ($RunEventId -eq [Guid]::Empty) { $RunEventId = [Guid]::NewGuid() }
    $ownsConnection = $null -eq $Connection
    $activeConnection = $Connection
    try {
        if($ownsConnection){$activeConnection = Open-DynomaxConnection -SqlConfig $SqlConfig}
        [void](Invoke-DynomaxSqlNonQuery -Connection $activeConnection -CommandText @'
IF NOT EXISTS (SELECT 1 FROM dmx.RunEvent WHERE RunEventId=@RunEventId)
BEGIN
    INSERT INTO dmx.RunEvent(RunEventId,RunId,ActionRunId,EventLevel,EventType,Message,DataJson,CreatedAtUtc)
    VALUES(@RunEventId,@RunId,NULL,@EventLevel,@EventType,@Message,@DataJson,SYSUTCDATETIME());
END
'@ -Parameters @{
            '@RunEventId' = $RunEventId
            '@RunId' = $RunId
            '@EventLevel' = $EventLevel.Trim()
            '@EventType' = $EventType.Trim()
            '@Message' = $Message
            '@DataJson' = $dataJson
        })
    }
    finally {
        if ($ownsConnection -and $activeConnection) { $activeConnection.Dispose() }
    }
}

function Add-DynomaxRunEventsBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$SqlConfig,
        [Parameter(Mandatory)][Guid]$RunId,
        [Parameter(Mandatory)][object[]]$Events,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    if ($Events.Count -eq 0) { return 0 }
    $payload = [System.Collections.Generic.List[object]]::new()
    foreach ($eventItem in @($Events)) {
        $eventId = [Guid](Get-DynomaxPropertyValue -Object $eventItem -Name 'runEventId' -DefaultValue ([Guid]::Empty))
        if ($eventId -eq [Guid]::Empty) { throw 'A deterministic Run event id is required for batched persistence.' }
        $eventLevel = [string](Get-DynomaxPropertyValue -Object $eventItem -Name 'eventLevel' -DefaultValue '')
        $eventType = [string](Get-DynomaxPropertyValue -Object $eventItem -Name 'eventType' -DefaultValue '')
        $message = [string](Get-DynomaxPropertyValue -Object $eventItem -Name 'message' -DefaultValue '')
        if ([string]::IsNullOrWhiteSpace($eventLevel) -or [string]::IsNullOrWhiteSpace($eventType) -or [string]::IsNullOrWhiteSpace($message)) {
            throw 'Batched Run events require level, type and message.'
        }
        $data = Get-DynomaxPropertyValue -Object $eventItem -Name 'data' -DefaultValue $null
        $payload.Add([ordered]@{
            runEventId = $eventId.ToString('D')
            eventLevel = $eventLevel.Trim()
            eventType = $eventType.Trim()
            message = $message
            dataJson = $(if ($null -eq $data) { $null } else { $data | ConvertTo-Json -Depth 20 -Compress })
        })
    }

    $eventsJson = $payload | ConvertTo-Json -Depth 30 -Compress
    $ownsConnection = $null -eq $Connection
    $activeConnection = $Connection
    try {
        if ($ownsConnection) { $activeConnection = Open-DynomaxConnection -SqlConfig $SqlConfig }
        $inserted = Invoke-DynomaxSqlScalar -Connection $activeConnection -CommandText @'
DECLARE @Inserted int = 0;
;WITH source AS
(
    SELECT RunEventId,EventLevel,EventType,Message,DataJson
    FROM OPENJSON(@EventsJson)
    WITH
    (
        RunEventId uniqueidentifier '$.runEventId',
        EventLevel nvarchar(32) '$.eventLevel',
        EventType nvarchar(200) '$.eventType',
        Message nvarchar(max) '$.message',
        DataJson nvarchar(max) '$.dataJson'
    )
)
INSERT INTO dmx.RunEvent(RunEventId,RunId,ActionRunId,EventLevel,EventType,Message,DataJson,CreatedAtUtc)
SELECT source.RunEventId,@RunId,NULL,source.EventLevel,source.EventType,source.Message,source.DataJson,SYSUTCDATETIME()
FROM source
WHERE source.RunEventId IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dmx.RunEvent existing WHERE existing.RunEventId=source.RunEventId);
SET @Inserted = @@ROWCOUNT;
SELECT @Inserted;
'@ -Parameters @{ '@RunId' = $RunId; '@EventsJson' = $eventsJson }
        return [int]$inserted
    }
    finally {
        if ($ownsConnection -and $activeConnection) { $activeConnection.Dispose() }
    }
}
