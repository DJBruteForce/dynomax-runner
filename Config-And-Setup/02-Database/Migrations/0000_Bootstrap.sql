IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dmx') EXEC(N'CREATE SCHEMA dmx AUTHORIZATION dbo;');
GO
IF OBJECT_ID(N'dmx.MigrationHistory',N'U') IS NULL
BEGIN
    CREATE TABLE dmx.MigrationHistory(
        MigrationId nvarchar(200) NOT NULL CONSTRAINT PK_MigrationHistory PRIMARY KEY,
        Checksum char(64) NOT NULL,
        AppliedAtUtc datetime2(3) NOT NULL,
        DurationMilliseconds int NOT NULL,
        Succeeded bit NOT NULL,
        ErrorMessage nvarchar(max) NULL
    );
END;
GO
