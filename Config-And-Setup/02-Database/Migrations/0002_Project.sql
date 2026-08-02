IF OBJECT_ID(N'dmx.Project',N'U') IS NULL
CREATE TABLE dmx.Project(
    ProjectId uniqueidentifier NOT NULL CONSTRAINT PK_Project PRIMARY KEY,
    ProjectKey nvarchar(200) NOT NULL,
    DisplayName nvarchar(300) NOT NULL,
    ProjectType nvarchar(100) NOT NULL,
    IsActive bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT UQ_Project_Key UNIQUE(ProjectKey)
);
GO
IF OBJECT_ID(N'dmx.ProjectVersion',N'U') IS NULL
CREATE TABLE dmx.ProjectVersion(
    ProjectVersionId uniqueidentifier NOT NULL CONSTRAINT PK_ProjectVersion PRIMARY KEY,
    ProjectId uniqueidentifier NOT NULL,
    VersionNumber int NOT NULL,
    DefinitionHash char(64) NOT NULL,
    DefinitionJson nvarchar(max) NOT NULL,
    IsCurrent bit NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_ProjectVersion_Project FOREIGN KEY(ProjectId) REFERENCES dmx.Project(ProjectId),
    CONSTRAINT UQ_ProjectVersion_Number UNIQUE(ProjectId,VersionNumber),
    CONSTRAINT UQ_ProjectVersion_Hash UNIQUE(ProjectId,DefinitionHash),
    CONSTRAINT CK_ProjectVersion_Json CHECK(ISJSON(DefinitionJson)=1)
);
GO
IF OBJECT_ID(N'dmx.ProjectEnvironment',N'U') IS NULL
CREATE TABLE dmx.ProjectEnvironment(
    ProjectEnvironmentId uniqueidentifier NOT NULL CONSTRAINT PK_ProjectEnvironment PRIMARY KEY,
    ProjectVersionId uniqueidentifier NOT NULL,
    EnvironmentKey nvarchar(100) NOT NULL,
    DisplayName nvarchar(200) NOT NULL,
    BaseUrl nvarchar(2000) NOT NULL,
    DefinitionJson nvarchar(max) NOT NULL,
    CONSTRAINT FK_ProjectEnvironment_ProjectVersion FOREIGN KEY(ProjectVersionId) REFERENCES dmx.ProjectVersion(ProjectVersionId),
    CONSTRAINT UQ_ProjectEnvironment_Key UNIQUE(ProjectVersionId,EnvironmentKey),
    CONSTRAINT CK_ProjectEnvironment_Json CHECK(ISJSON(DefinitionJson)=1)
);
GO
IF OBJECT_ID(N'dmx.ProjectSequence',N'U') IS NULL
CREATE TABLE dmx.ProjectSequence(
    ProjectId uniqueidentifier NOT NULL CONSTRAINT PK_ProjectSequence PRIMARY KEY,
    NextSessionNumber bigint NOT NULL CONSTRAINT DF_ProjectSequence_Next DEFAULT(1),
    CONSTRAINT FK_ProjectSequence_Project FOREIGN KEY(ProjectId) REFERENCES dmx.Project(ProjectId),
    CONSTRAINT CK_ProjectSequence_Positive CHECK(NextSessionNumber>0)
);
GO
