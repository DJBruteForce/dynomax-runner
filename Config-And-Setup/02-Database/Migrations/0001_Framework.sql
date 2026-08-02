IF OBJECT_ID(N'dmx.FrameworkVersion',N'U') IS NULL
CREATE TABLE dmx.FrameworkVersion(
    FrameworkVersionId uniqueidentifier NOT NULL CONSTRAINT PK_FrameworkVersion PRIMARY KEY,
    VersionNumber nvarchar(50) NOT NULL,
    InstalledAtUtc datetime2(3) NOT NULL,
    IsCurrent bit NOT NULL,
    CONSTRAINT UQ_FrameworkVersion_Version UNIQUE(VersionNumber)
);
GO
IF OBJECT_ID(N'dmx.FrameworkSetting',N'U') IS NULL
CREATE TABLE dmx.FrameworkSetting(
    SettingKey nvarchar(200) NOT NULL CONSTRAINT PK_FrameworkSetting PRIMARY KEY,
    ValueJson nvarchar(max) NOT NULL,
    UpdatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT CK_FrameworkSetting_ValueJson CHECK(ISJSON(ValueJson)=1)
);
GO
IF OBJECT_ID(N'dmx.Machine',N'U') IS NULL
CREATE TABLE dmx.Machine(
    MachineId uniqueidentifier NOT NULL CONSTRAINT PK_Machine PRIMARY KEY,
    MachineName nvarchar(200) NOT NULL,
    OsVersion nvarchar(500) NOT NULL,
    PowerShellVersion nvarchar(100) NOT NULL,
    LastSeenAtUtc datetime2(3) NOT NULL,
    CONSTRAINT UQ_Machine_Name UNIQUE(MachineName)
);
GO
