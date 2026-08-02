
IF OBJECT_ID(N'dmx.ActionSourceFingerprint',N'U') IS NULL
CREATE TABLE dmx.ActionSourceFingerprint(
    ActionSourceFingerprintId uniqueidentifier NOT NULL CONSTRAINT PK_ActionSourceFingerprint PRIMARY KEY,
    ActionVersionId uniqueidentifier NOT NULL,
    DependencyKey nvarchar(300) NOT NULL,
    SourcePath nvarchar(2000) NOT NULL,
    Sha256 char(64) NOT NULL,
    IsRequired bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_ActionSourceFingerprint_ActionVersion FOREIGN KEY(ActionVersionId) REFERENCES dmx.ActionVersion(ActionVersionId),
    CONSTRAINT UQ_ActionSourceFingerprint_Key UNIQUE(ActionVersionId,DependencyKey)
);
GO
IF OBJECT_ID(N'dmx.ActionCertification',N'U') IS NULL
CREATE TABLE dmx.ActionCertification(
    ActionCertificationId uniqueidentifier NOT NULL CONSTRAINT PK_ActionCertification PRIMARY KEY,
    ActionVersionId uniqueidentifier NOT NULL,
    EnvironmentKey nvarchar(100) NOT NULL,
    MachineName nvarchar(200) NOT NULL,
    Status nvarchar(50) NOT NULL,
    CertifiedAtUtc datetime2(3) NOT NULL,
    DetailsJson nvarchar(max) NULL,
    CONSTRAINT FK_ActionCertification_ActionVersion FOREIGN KEY(ActionVersionId) REFERENCES dmx.ActionVersion(ActionVersionId),
    CONSTRAINT CK_ActionCertification_Status CHECK(Status IN('CERTIFIED','STALE','REVOKED')),
    CONSTRAINT CK_ActionCertification_Json CHECK(DetailsJson IS NULL OR ISJSON(DetailsJson)=1)
);
GO
IF OBJECT_ID(N'dmx.Assertion',N'U') IS NULL
CREATE TABLE dmx.Assertion(
    AssertionId uniqueidentifier NOT NULL CONSTRAINT PK_Assertion PRIMARY KEY,
    ActionRunId uniqueidentifier NOT NULL,
    AssertionName nvarchar(500) NOT NULL,
    ExpectedValue nvarchar(max) NULL,
    ActualValue nvarchar(max) NULL,
    Passed bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_Assertion_ActionRun FOREIGN KEY(ActionRunId) REFERENCES dmx.ActionRun(ActionRunId)
);
GO
IF OBJECT_ID(N'dmx.RunEvent',N'U') IS NULL
CREATE TABLE dmx.RunEvent(
    RunEventId uniqueidentifier NOT NULL CONSTRAINT PK_RunEvent PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    ActionRunId uniqueidentifier NULL,
    EventLevel nvarchar(50) NOT NULL,
    EventType nvarchar(100) NOT NULL,
    Message nvarchar(max) NOT NULL,
    DataJson nvarchar(max) NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_RunEvent_TestRun FOREIGN KEY(RunId) REFERENCES dmx.TestRun(RunId),
    CONSTRAINT FK_RunEvent_ActionRun FOREIGN KEY(ActionRunId) REFERENCES dmx.ActionRun(ActionRunId),
    CONSTRAINT CK_RunEvent_DataJson CHECK(DataJson IS NULL OR ISJSON(DataJson)=1)
);
GO
IF OBJECT_ID(N'dmx.CleanupRegistration',N'U') IS NULL
CREATE TABLE dmx.CleanupRegistration(
    CleanupRegistrationId uniqueidentifier NOT NULL CONSTRAINT PK_CleanupRegistration PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    SourceActionRunId uniqueidentifier NULL,
    CleanupActionKey nvarchar(300) NOT NULL,
    ObjectType nvarchar(200) NULL,
    ObjectIdentifier nvarchar(1000) NULL,
    RegistrationJson nvarchar(max) NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_CleanupRegistration_TestRun FOREIGN KEY(RunId) REFERENCES dmx.TestRun(RunId),
    CONSTRAINT FK_CleanupRegistration_ActionRun FOREIGN KEY(SourceActionRunId) REFERENCES dmx.ActionRun(ActionRunId),
    CONSTRAINT CK_CleanupRegistration_Json CHECK(ISJSON(RegistrationJson)=1)
);
GO
IF OBJECT_ID(N'dmx.CleanupRun',N'U') IS NULL
CREATE TABLE dmx.CleanupRun(
    CleanupRunId uniqueidentifier NOT NULL CONSTRAINT PK_CleanupRun PRIMARY KEY,
    CleanupRegistrationId uniqueidentifier NOT NULL,
    Status nvarchar(50) NOT NULL,
    StartedAtUtc datetime2(3) NOT NULL,
    EndedAtUtc datetime2(3) NULL,
    Message nvarchar(max) NULL,
    CONSTRAINT FK_CleanupRun_Registration FOREIGN KEY(CleanupRegistrationId) REFERENCES dmx.CleanupRegistration(CleanupRegistrationId),
    CONSTRAINT CK_CleanupRun_Status CHECK(Status IN('PASS','FAIL','ERROR','SKIPPED'))
);
GO
IF OBJECT_ID(N'dmx.RetentionPolicy',N'U') IS NULL
CREATE TABLE dmx.RetentionPolicy(
    RetentionPolicyId uniqueidentifier NOT NULL CONSTRAINT PK_RetentionPolicy PRIMARY KEY,
    PolicyKey nvarchar(200) NOT NULL,
    RetainDays int NOT NULL,
    MaximumArtifactBytes bigint NULL,
    IsEnabled bit NOT NULL,
    UpdatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT UQ_RetentionPolicy_Key UNIQUE(PolicyKey),
    CONSTRAINT CK_RetentionPolicy_Days CHECK(RetainDays>0)
);
GO
IF NOT EXISTS(SELECT 1 FROM dmx.RetentionPolicy WHERE PolicyKey=N'DefaultRunEvidence')
INSERT INTO dmx.RetentionPolicy(RetentionPolicyId,PolicyKey,RetainDays,MaximumArtifactBytes,IsEnabled,UpdatedAtUtc)
VALUES(NEWID(),N'DefaultRunEvidence',90,5368709120,1,SYSUTCDATETIME());
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.RunEvent') AND name=N'IX_RunEvent_RunCreated') CREATE INDEX IX_RunEvent_RunCreated ON dmx.RunEvent(RunId,CreatedAtUtc) INCLUDE(ActionRunId,EventLevel,EventType);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.ActionCertification') AND name=N'IX_ActionCertification_ActionEnvironment') CREATE INDEX IX_ActionCertification_ActionEnvironment ON dmx.ActionCertification(ActionVersionId,EnvironmentKey,CertifiedAtUtc DESC) INCLUDE(Status,MachineName);
GO
