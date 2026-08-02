IF OBJECT_ID(N'dmx.Action',N'U') IS NULL
CREATE TABLE dmx.Action(
    ActionId uniqueidentifier NOT NULL CONSTRAINT PK_Action PRIMARY KEY,
    ProjectId uniqueidentifier NOT NULL,
    ActionKey nvarchar(300) NOT NULL,
    DisplayName nvarchar(300) NOT NULL,
    IsActive bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_Action_Project FOREIGN KEY(ProjectId) REFERENCES dmx.Project(ProjectId),
    CONSTRAINT UQ_Action_Key UNIQUE(ProjectId,ActionKey)
);
GO
IF OBJECT_ID(N'dmx.ActionVersion',N'U') IS NULL
CREATE TABLE dmx.ActionVersion(
    ActionVersionId uniqueidentifier NOT NULL CONSTRAINT PK_ActionVersion PRIMARY KEY,
    ActionId uniqueidentifier NOT NULL,
    VersionNumber int NOT NULL,
    Engine nvarchar(100) NOT NULL,
    EntryPoint nvarchar(1000) NOT NULL,
    KeywordName nvarchar(500) NULL,
    SessionBehavior nvarchar(100) NOT NULL,
    DefinitionHash char(64) NOT NULL,
    ImplementationHash char(64) NOT NULL,
    DefinitionJson nvarchar(max) NOT NULL,
    IsCurrent bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_ActionVersion_Action FOREIGN KEY(ActionId) REFERENCES dmx.Action(ActionId),
    CONSTRAINT UQ_ActionVersion_Number UNIQUE(ActionId,VersionNumber),
    CONSTRAINT UQ_ActionVersion_Hash UNIQUE(ActionId,DefinitionHash,ImplementationHash),
    CONSTRAINT CK_ActionVersion_Json CHECK(ISJSON(DefinitionJson)=1)
);
GO
IF OBJECT_ID(N'dmx.Workflow',N'U') IS NULL
CREATE TABLE dmx.Workflow(
    WorkflowId uniqueidentifier NOT NULL CONSTRAINT PK_Workflow PRIMARY KEY,
    ProjectId uniqueidentifier NOT NULL,
    WorkflowKey nvarchar(300) NOT NULL,
    DisplayName nvarchar(300) NOT NULL,
    IsActive bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_Workflow_Project FOREIGN KEY(ProjectId) REFERENCES dmx.Project(ProjectId),
    CONSTRAINT UQ_Workflow_Key UNIQUE(ProjectId,WorkflowKey)
);
GO
IF OBJECT_ID(N'dmx.WorkflowVersion',N'U') IS NULL
CREATE TABLE dmx.WorkflowVersion(
    WorkflowVersionId uniqueidentifier NOT NULL CONSTRAINT PK_WorkflowVersion PRIMARY KEY,
    WorkflowId uniqueidentifier NOT NULL,
    VersionNumber int NOT NULL,
    EnvironmentKey nvarchar(100) NOT NULL,
    DefinitionHash char(64) NOT NULL,
    DefinitionJson nvarchar(max) NOT NULL,
    IsCurrent bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_WorkflowVersion_Workflow FOREIGN KEY(WorkflowId) REFERENCES dmx.Workflow(WorkflowId),
    CONSTRAINT UQ_WorkflowVersion_Number UNIQUE(WorkflowId,VersionNumber),
    CONSTRAINT UQ_WorkflowVersion_Hash UNIQUE(WorkflowId,DefinitionHash),
    CONSTRAINT CK_WorkflowVersion_Json CHECK(ISJSON(DefinitionJson)=1)
);
GO
IF OBJECT_ID(N'dmx.WorkflowStep',N'U') IS NULL
CREATE TABLE dmx.WorkflowStep(
    WorkflowStepId uniqueidentifier NOT NULL CONSTRAINT PK_WorkflowStep PRIMARY KEY,
    WorkflowVersionId uniqueidentifier NOT NULL,
    StepOrder int NOT NULL,
    ActionKey nvarchar(300) NOT NULL,
    RequestedActionVersion int NULL,
    IsCleanup bit NOT NULL,
    ContinueOnFailure bit NOT NULL,
    DefinitionJson nvarchar(max) NOT NULL,
    CONSTRAINT FK_WorkflowStep_WorkflowVersion FOREIGN KEY(WorkflowVersionId) REFERENCES dmx.WorkflowVersion(WorkflowVersionId),
    CONSTRAINT UQ_WorkflowStep_Order UNIQUE(WorkflowVersionId,StepOrder),
    CONSTRAINT CK_WorkflowStep_Json CHECK(ISJSON(DefinitionJson)=1)
);
GO
