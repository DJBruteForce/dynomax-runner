IF OBJECT_ID(N'dmx.TestRun',N'U') IS NULL
CREATE TABLE dmx.TestRun(
    RunId uniqueidentifier NOT NULL CONSTRAINT PK_TestRun PRIMARY KEY,
    ProjectId uniqueidentifier NOT NULL,
    WorkflowVersionId uniqueidentifier NULL,
    MachineName nvarchar(200) NOT NULL,
    EnvironmentKey nvarchar(100) NOT NULL,
    Status nvarchar(50) NOT NULL,
    StartedAtUtc datetime2(3) NOT NULL,
    EndedAtUtc datetime2(3) NULL,
    WorkingDirectory nvarchar(2000) NOT NULL,
    PackageHash char(64) NOT NULL,
    Summary nvarchar(max) NULL,
    CONSTRAINT FK_TestRun_Project FOREIGN KEY(ProjectId) REFERENCES dmx.Project(ProjectId),
    CONSTRAINT FK_TestRun_WorkflowVersion FOREIGN KEY(WorkflowVersionId) REFERENCES dmx.WorkflowVersion(WorkflowVersionId),
    CONSTRAINT CK_TestRun_Status CHECK(Status IN('RUNNING','PASS','FAIL','TEST_INVALID','BLOCKED','ERROR','STALE','SKIPPED','CLEANUP_FAILED'))
);
GO
IF OBJECT_ID(N'dmx.ActionRun',N'U') IS NULL
CREATE TABLE dmx.ActionRun(
    ActionRunId uniqueidentifier NOT NULL CONSTRAINT PK_ActionRun PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    StepOrder int NOT NULL,
    ActionVersionId uniqueidentifier NULL,
    ActionKey nvarchar(300) NOT NULL,
    Status nvarchar(50) NOT NULL,
    IsCleanup bit NOT NULL,
    StartedAtUtc datetime2(3) NOT NULL,
    EndedAtUtc datetime2(3) NULL,
    Message nvarchar(max) NULL,
    OutputJson nvarchar(max) NULL,
    CONSTRAINT FK_ActionRun_TestRun FOREIGN KEY(RunId) REFERENCES dmx.TestRun(RunId),
    CONSTRAINT FK_ActionRun_ActionVersion FOREIGN KEY(ActionVersionId) REFERENCES dmx.ActionVersion(ActionVersionId),
    CONSTRAINT CK_ActionRun_Status CHECK(Status IN('PASS','FAIL','TEST_INVALID','BLOCKED','ERROR','STALE','SKIPPED','CLEANUP_FAILED')),
    CONSTRAINT CK_ActionRun_OutputJson CHECK(OutputJson IS NULL OR ISJSON(OutputJson)=1)
);
GO
IF OBJECT_ID(N'dmx.RunContextValue',N'U') IS NULL
CREATE TABLE dmx.RunContextValue(
    RunContextValueId uniqueidentifier NOT NULL CONSTRAINT PK_RunContextValue PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    ContextKey nvarchar(300) NOT NULL,
    ValueJson nvarchar(max) NOT NULL,
    IsSecret bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    UpdatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_RunContextValue_TestRun FOREIGN KEY(RunId) REFERENCES dmx.TestRun(RunId),
    CONSTRAINT UQ_RunContextValue_Key UNIQUE(RunId,ContextKey),
    CONSTRAINT CK_RunContextValue_Json CHECK(ISJSON(ValueJson)=1)
);
GO
