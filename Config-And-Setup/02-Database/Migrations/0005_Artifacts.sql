IF OBJECT_ID(N'dmx.ArtifactContent',N'U') IS NULL
CREATE TABLE dmx.ArtifactContent(
    ArtifactContentId uniqueidentifier NOT NULL CONSTRAINT PK_ArtifactContent PRIMARY KEY,
    Sha256 char(64) NOT NULL,
    OriginalLength bigint NOT NULL,
    StoredLength bigint NOT NULL,
    CompressionType nvarchar(50) NOT NULL,
    Content varbinary(max) NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT UQ_ArtifactContent_Hash UNIQUE(Sha256),
    CONSTRAINT CK_ArtifactContent_Length CHECK(OriginalLength>=0 AND StoredLength>=0)
);
GO
IF OBJECT_ID(N'dmx.Artifact',N'U') IS NULL
CREATE TABLE dmx.Artifact(
    ArtifactId uniqueidentifier NOT NULL CONSTRAINT PK_Artifact PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    ActionKey nvarchar(300) NULL,
    ArtifactContentId uniqueidentifier NOT NULL,
    ArtifactType nvarchar(100) NOT NULL,
    OriginalFileName nvarchar(1000) NOT NULL,
    MimeType nvarchar(200) NOT NULL,
    CreatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT FK_Artifact_TestRun FOREIGN KEY(RunId) REFERENCES dmx.TestRun(RunId),
    CONSTRAINT FK_Artifact_Content FOREIGN KEY(ArtifactContentId) REFERENCES dmx.ArtifactContent(ArtifactContentId)
);
GO
