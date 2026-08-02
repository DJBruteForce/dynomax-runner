IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.ProjectVersion') AND name=N'IX_ProjectVersion_Current') CREATE INDEX IX_ProjectVersion_Current ON dmx.ProjectVersion(ProjectId,IsCurrent) INCLUDE(VersionNumber,DefinitionHash);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.ActionVersion') AND name=N'IX_ActionVersion_Current') CREATE INDEX IX_ActionVersion_Current ON dmx.ActionVersion(ActionId,IsCurrent) INCLUDE(VersionNumber,Engine,DefinitionHash,ImplementationHash);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.WorkflowVersion') AND name=N'IX_WorkflowVersion_Current') CREATE INDEX IX_WorkflowVersion_Current ON dmx.WorkflowVersion(WorkflowId,IsCurrent) INCLUDE(VersionNumber,DefinitionHash);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.TestRun') AND name=N'IX_TestRun_ProjectStarted') CREATE INDEX IX_TestRun_ProjectStarted ON dmx.TestRun(ProjectId,StartedAtUtc DESC) INCLUDE(Status,EnvironmentKey,WorkflowVersionId);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.ActionRun') AND name=N'IX_ActionRun_RunStep') CREATE INDEX IX_ActionRun_RunStep ON dmx.ActionRun(RunId,StepOrder,StartedAtUtc) INCLUDE(Status,ActionKey,IsCleanup);
GO
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dmx.Artifact') AND name=N'IX_Artifact_Run') CREATE INDEX IX_Artifact_Run ON dmx.Artifact(RunId,CreatedAtUtc) INCLUDE(ArtifactType,ActionKey,ArtifactContentId);
GO
