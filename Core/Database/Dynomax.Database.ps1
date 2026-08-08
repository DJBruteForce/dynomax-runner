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
        [Guid]$RunEventId = [Guid]::Empty
    )

    if ([string]::IsNullOrWhiteSpace($EventLevel)) { throw 'Run event level is required.' }
    if ([string]::IsNullOrWhiteSpace($EventType)) { throw 'Run event type is required.' }
    if ([string]::IsNullOrWhiteSpace($Message)) { throw 'Run event message is required.' }

    $dataJson = if ($null -eq $Data) { $null } else { $Data | ConvertTo-Json -Depth 12 -Compress }
    if ($RunEventId -eq [Guid]::Empty) { $RunEventId = [Guid]::NewGuid() }
    $connection = $null
    try {
        $connection = Open-DynomaxConnection -SqlConfig $SqlConfig
        [void](Invoke-DynomaxSqlNonQuery -Connection $connection -CommandText @'
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
        if ($connection) { $connection.Dispose() }
    }
}
