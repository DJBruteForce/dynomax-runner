IF OBJECT_ID(N'dmx.FrameworkValidationRun',N'U') IS NULL
CREATE TABLE dmx.FrameworkValidationRun(
    ValidationRunId uniqueidentifier NOT NULL CONSTRAINT PK_FrameworkValidationRun PRIMARY KEY,
    FrameworkVersion nvarchar(50) NOT NULL,
    MachineName nvarchar(200) NOT NULL,
    ValidationType nvarchar(100) NOT NULL,
    Status nvarchar(50) NOT NULL,
    StartedAtUtc datetime2(3) NOT NULL,
    EndedAtUtc datetime2(3) NULL,
    Summary nvarchar(max) NULL,
    ResultJson nvarchar(max) NULL,
    CONSTRAINT CK_FrameworkValidationRun_Status CHECK(Status IN('RUNNING','PASS','ERROR')),
    CONSTRAINT CK_FrameworkValidationRun_ResultJson CHECK(ResultJson IS NULL OR ISJSON(ResultJson)=1)
);
GO
IF OBJECT_ID(N'dmx.FrameworkValidationArtifact',N'U') IS NULL
CREATE TABLE dmx.FrameworkValidationArtifact(
    FrameworkValidationArtifactId uniqueidentifier NOT NULL CONSTRAINT PK_FrameworkValidationArtifact PRIMARY KEY,
    ValidationRunId uniqueidentifier NOT NULL,
    ArtifactContentId uniqueidentifier NOT NULL,
    ArtifactType nvarchar(100) NOT NULL,
    OriginalFileName nvarchar(1000) NOT NULL,
    MimeType nvarchar(200) NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_FrameworkValidationArtifact_Run FOREIGN KEY(ValidationRunId) REFERENCES dmx.FrameworkValidationRun(ValidationRunId),
    CONSTRAINT FK_FrameworkValidationArtifact_Content FOREIGN KEY(ArtifactContentId) REFERENCES dmx.ArtifactContent(ArtifactContentId)
);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_FrameworkValidationRun_Started' AND object_id=OBJECT_ID(N'dmx.FrameworkValidationRun'))
CREATE INDEX IX_FrameworkValidationRun_Started ON dmx.FrameworkValidationRun(StartedAtUtc DESC);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name=N'IX_FrameworkValidationArtifact_Run' AND object_id=OBJECT_ID(N'dmx.FrameworkValidationArtifact'))
CREATE INDEX IX_FrameworkValidationArtifact_Run ON dmx.FrameworkValidationArtifact(ValidationRunId,CreatedAtUtc);
GO
