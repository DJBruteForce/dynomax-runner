using Dynomax.Domain.Common;

namespace Dynomax.Domain.ProjectContext;

public static class RepositoryProviders
{
    public const string GitHub = "GitHub";
}

public static class RepositoryWorkspaceStates
{
    public const string Preparing = "Preparing";
    public const string Clean = "Clean";
    public const string Modified = "Modified";
    public const string Conflicted = "Conflicted";
    public const string Rebasing = "Rebasing";
    public const string Committed = "Committed";
    public const string Pushed = "Pushed";
    public const string PullRequestCreated = "PRCreated";
    public const string Closed = "Closed";
    public const string Failed = "Failed";
}

public sealed class ProjectContextRepository : Entity
{
    private ProjectContextRepository() { }

    public ProjectContextRepository(Guid sourceId, string provider, string providerRepositoryId, string owner, string name,
        string fullName, string webUrl, string cloneUrl, string visibility, bool isArchived, bool isDisabled, bool? isFork,
        string? providerDescription, string? role, string? purpose, string? tagsJson, string? defaultBranch,
        string? defaultBranchHeadSha, string? defaultTreeSha, Guid credentialSecretReferenceId, Guid createdByUserId, DateTime createdAtUtc)
    {
        RepositoryEntityValues.GuidRequired(sourceId, nameof(sourceId));
        RepositoryEntityValues.GuidRequired(credentialSecretReferenceId, nameof(credentialSecretReferenceId));
        RepositoryEntityValues.GuidRequired(createdByUserId, nameof(createdByUserId));
        SourceId = sourceId;
        Provider = RepositoryEntityValues.Required(provider, 30, nameof(provider));
        ProviderRepositoryId = RepositoryEntityValues.Required(providerRepositoryId, 100, nameof(providerRepositoryId));
        Owner = RepositoryEntityValues.Required(owner, 100, nameof(owner));
        Name = RepositoryEntityValues.Required(name, 100, nameof(name));
        FullName = RepositoryEntityValues.Required(fullName, 220, nameof(fullName));
        WebUrl = RepositoryEntityValues.Required(webUrl, 500, nameof(webUrl));
        CloneUrl = RepositoryEntityValues.Required(cloneUrl, 500, nameof(cloneUrl));
        Visibility = RepositoryEntityValues.Required(visibility, 30, nameof(visibility));
        IsArchived = isArchived; IsDisabled = isDisabled; IsFork = isFork;
        ProviderDescription = RepositoryEntityValues.Optional(providerDescription, 1000);
        Role = RepositoryEntityValues.Optional(role, 100);
        Purpose = RepositoryEntityValues.Optional(purpose, 1000);
        TagsJson = string.IsNullOrWhiteSpace(tagsJson) ? "[]" : tagsJson.Trim();
        DefaultBranch = RepositoryEntityValues.Optional(defaultBranch, 255);
        DefaultBranchHeadSha = RepositoryEntityValues.OptionalSha(defaultBranchHeadSha, nameof(defaultBranchHeadSha));
        DefaultTreeSha = RepositoryEntityValues.OptionalSha(defaultTreeSha, nameof(defaultTreeSha));
        CredentialSecretReferenceId = credentialSecretReferenceId;
        HealthStatus = "Unknown";
        IsActive = true;
        CreatedByUserId = createdByUserId; UpdatedByUserId = createdByUserId;
        CreatedAtUtc = createdAtUtc; UpdatedAtUtc = createdAtUtc;
    }

    public Guid SourceId { get; private set; }
    public string Provider { get; private set; } = string.Empty;
    public string ProviderRepositoryId { get; private set; } = string.Empty;
    public string Owner { get; private set; } = string.Empty;
    public string Name { get; private set; } = string.Empty;
    public string FullName { get; private set; } = string.Empty;
    public string WebUrl { get; private set; } = string.Empty;
    public string CloneUrl { get; private set; } = string.Empty;
    public string Visibility { get; private set; } = string.Empty;
    public bool IsArchived { get; private set; }
    public bool IsDisabled { get; private set; }
    public bool? IsFork { get; private set; }
    public string? ProviderDescription { get; private set; }
    public string? Role { get; private set; }
    public string? Purpose { get; private set; }
    public string TagsJson { get; private set; } = "[]";
    public string? DefaultBranch { get; private set; }
    public string? DefaultBranchHeadSha { get; private set; }
    public string? DefaultTreeSha { get; private set; }
    public Guid CredentialSecretReferenceId { get; private set; }
    public string HealthStatus { get; private set; } = "Unknown";
    public string? LastErrorCode { get; private set; }
    public DateTime? LastValidatedAtUtc { get; private set; }
    public DateTime? LastRefreshedAtUtc { get; private set; }
    public bool IsActive { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public Guid UpdatedByUserId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public void SetProviderSnapshot(string owner, string name, string fullName, string webUrl, string cloneUrl,
        string visibility, bool isArchived, bool isDisabled, bool? isFork, string? providerDescription,
        string? defaultBranch, string? defaultBranchHeadSha, string? defaultTreeSha,
        string healthStatus, string? lastErrorCode, DateTime? validatedAtUtc, DateTime? refreshedAtUtc,
        Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        Owner = RepositoryEntityValues.Required(owner, 100, nameof(owner));
        Name = RepositoryEntityValues.Required(name, 100, nameof(name));
        FullName = RepositoryEntityValues.Required(fullName, 220, nameof(fullName));
        WebUrl = RepositoryEntityValues.Required(webUrl, 500, nameof(webUrl));
        CloneUrl = RepositoryEntityValues.Required(cloneUrl, 500, nameof(cloneUrl));
        Visibility = RepositoryEntityValues.Required(visibility, 30, nameof(visibility));
        IsArchived = isArchived; IsDisabled = isDisabled; IsFork = isFork;
        ProviderDescription = RepositoryEntityValues.Optional(providerDescription, 1000);
        SetRefreshState(defaultBranch, defaultBranchHeadSha, defaultTreeSha, healthStatus, lastErrorCode, validatedAtUtc, refreshedAtUtc, actorUserId, changedAtUtc);
    }

    public void SetCredentialSecretReference(Guid credentialSecretReferenceId, Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(credentialSecretReferenceId, nameof(credentialSecretReferenceId));
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        CredentialSecretReferenceId = credentialSecretReferenceId;
        UpdatedByUserId = actorUserId; UpdatedAtUtc = changedAtUtc;
    }

    public void SetActive(bool active, string healthStatus, Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        IsActive = active;
        HealthStatus = RepositoryEntityValues.Required(healthStatus, 50, nameof(healthStatus));
        if (active) LastErrorCode = null;
        UpdatedByUserId = actorUserId; UpdatedAtUtc = changedAtUtc;
    }
    public void SetContextMetadata(string? role, string? purpose, string? tagsJson, Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        Role = RepositoryEntityValues.Optional(role, 100); Purpose = RepositoryEntityValues.Optional(purpose, 1000);
        TagsJson = string.IsNullOrWhiteSpace(tagsJson) ? "[]" : tagsJson.Trim();
        UpdatedByUserId = actorUserId; UpdatedAtUtc = changedAtUtc;
    }

    public void SetRefreshState(string? defaultBranch, string? defaultBranchHeadSha, string? defaultTreeSha,
        string healthStatus, string? lastErrorCode, DateTime? validatedAtUtc, DateTime? refreshedAtUtc,
        Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        DefaultBranch = RepositoryEntityValues.Optional(defaultBranch, 255);
        DefaultBranchHeadSha = RepositoryEntityValues.OptionalSha(defaultBranchHeadSha, nameof(defaultBranchHeadSha));
        DefaultTreeSha = RepositoryEntityValues.OptionalSha(defaultTreeSha, nameof(defaultTreeSha));
        HealthStatus = RepositoryEntityValues.Required(healthStatus, 50, nameof(healthStatus));
        LastErrorCode = RepositoryEntityValues.Optional(lastErrorCode, 100);
        LastValidatedAtUtc = validatedAtUtc; LastRefreshedAtUtc = refreshedAtUtc;
        UpdatedByUserId = actorUserId; UpdatedAtUtc = changedAtUtc;
    }
}

public sealed class ProjectContextRepositoryPolicy : Entity
{
    private ProjectContextRepositoryPolicy() { }
    public ProjectContextRepositoryPolicy(Guid repositoryContextId, Guid createdByUserId, DateTime createdAtUtc)
    {
        RepositoryEntityValues.GuidRequired(repositoryContextId, nameof(repositoryContextId));
        RepositoryEntityValues.GuidRequired(createdByUserId, nameof(createdByUserId));
        RepositoryContextId = repositoryContextId;
        AllowRead = true; AllowWorkspace = true; AllowCommitPush = true; AllowPullRequest = true;
        AllowMerge = false; AllowRemoteBranchDelete = false; AllowActionsRerun = false;
        AllowDirectDefaultBranchWrite = false; AllowForcePush = false; RequirePullRequestForDefaultBranch = true;
        AllowedTargetBranchPatternsJson = "[]"; AllowedBaseBranchPatternsJson = "[]"; AgentBranchPrefix = "dynomax/";
        CreatedByUserId = createdByUserId; UpdatedByUserId = createdByUserId; CreatedAtUtc = createdAtUtc; UpdatedAtUtc = createdAtUtc;
    }
    public void UpdateSafeSettings(bool allowRead, bool allowWorkspace, bool allowCommitPush, bool allowPullRequest,
        bool allowMerge, bool allowRemoteBranchDelete, bool allowActionsRerun, bool allowDirectDefaultBranchWrite,
        bool allowForcePush, bool requirePullRequestForDefaultBranch, string targetPatternsJson, string basePatternsJson,
        string agentBranchPrefix, Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        if (allowMerge || allowRemoteBranchDelete || allowActionsRerun || allowDirectDefaultBranchWrite || allowForcePush)
            throw new InvalidOperationException("High-risk repository policy enables are not available before their dedicated P031 authorization steps.");
        AllowRead = allowRead; AllowWorkspace = allowWorkspace; AllowCommitPush = allowCommitPush; AllowPullRequest = allowPullRequest;
        AllowMerge = false; AllowRemoteBranchDelete = false; AllowActionsRerun = false;
        AllowDirectDefaultBranchWrite = false; AllowForcePush = false;
        RequirePullRequestForDefaultBranch = requirePullRequestForDefaultBranch;
        AllowedTargetBranchPatternsJson = RepositoryEntityValues.Required(targetPatternsJson, 4000, nameof(targetPatternsJson));
        AllowedBaseBranchPatternsJson = RepositoryEntityValues.Required(basePatternsJson, 4000, nameof(basePatternsJson));
        AgentBranchPrefix = RepositoryEntityValues.Required(agentBranchPrefix, 100, nameof(agentBranchPrefix));
        UpdatedByUserId = actorUserId; UpdatedAtUtc = changedAtUtc;
    }
    public Guid RepositoryContextId { get; private set; }
    public bool AllowRead { get; private set; }
    public bool AllowWorkspace { get; private set; }
    public bool AllowCommitPush { get; private set; }
    public bool AllowPullRequest { get; private set; }
    public bool AllowMerge { get; private set; }
    public bool AllowRemoteBranchDelete { get; private set; }
    public bool AllowActionsRerun { get; private set; }
    public bool AllowDirectDefaultBranchWrite { get; private set; }
    public bool AllowForcePush { get; private set; }
    public bool RequirePullRequestForDefaultBranch { get; private set; }
    public string AllowedTargetBranchPatternsJson { get; private set; } = "[]";
    public string AllowedBaseBranchPatternsJson { get; private set; } = "[]";
    public string AgentBranchPrefix { get; private set; } = "dynomax/";
    public Guid CreatedByUserId { get; private set; }
    public Guid UpdatedByUserId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];
}

public sealed class RepositoryWorkSet : Entity
{
    private RepositoryWorkSet() { }
    public RepositoryWorkSet(Guid projectId, string title, string goal, Guid ownerUserId, Guid? agentAccessGrantId,
        Guid? changeManagementActorId, Guid? linkedProjectIssueId, Guid? linkedProductChangeId, Guid? linkedTestingStepId,
        DateTime createdAtUtc, DateTime? expiresAtUtc = null)
    {
        RepositoryEntityValues.GuidRequired(projectId, nameof(projectId)); RepositoryEntityValues.GuidRequired(ownerUserId, nameof(ownerUserId));
        ProjectId = projectId; Title = RepositoryEntityValues.Required(title, 200, nameof(title)); Goal = RepositoryEntityValues.Required(goal, 4000, nameof(goal));
        OwnerUserId = ownerUserId; AgentAccessGrantId = agentAccessGrantId; ChangeManagementActorId = changeManagementActorId;
        LinkedProjectIssueId = linkedProjectIssueId; LinkedProductChangeId = linkedProductChangeId; LinkedTestingStepId = linkedTestingStepId;
        Status = "Active"; CreatedAtUtc = createdAtUtc; UpdatedAtUtc = createdAtUtc; ExpiresAtUtc = expiresAtUtc;
    }
    public Guid ProjectId { get; private set; }
    public string Title { get; private set; } = string.Empty;
    public string Goal { get; private set; } = string.Empty;
    public Guid OwnerUserId { get; private set; }
    public Guid? AgentAccessGrantId { get; private set; }
    public Guid? ChangeManagementActorId { get; private set; }
    public Guid? LinkedProjectIssueId { get; private set; }
    public Guid? LinkedProductChangeId { get; private set; }
    public Guid? LinkedTestingStepId { get; private set; }
    public string Status { get; private set; } = "Active";
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public DateTime? ExpiresAtUtc { get; private set; }
    public void SetStatus(string status, DateTime changedAtUtc)
    {
        Status = RepositoryEntityValues.Required(status, 50, nameof(status));
        UpdatedAtUtc = changedAtUtc;
    }    public byte[] RowVersion { get; private set; } = [];
}

public sealed class RepositoryWorkspace : Entity
{
    private RepositoryWorkspace() { }
    public RepositoryWorkspace(Guid workSetId, Guid repositoryContextId, string storageKey, string baseBranch, string baseCommitSha,
        string workBranch, string? remoteTargetBranch, Guid createdByUserId, Guid? agentAccessGrantId, Guid? changeManagementActorId, DateTime createdAtUtc)
    {
        RepositoryEntityValues.GuidRequired(workSetId, nameof(workSetId)); RepositoryEntityValues.GuidRequired(repositoryContextId, nameof(repositoryContextId)); RepositoryEntityValues.GuidRequired(createdByUserId, nameof(createdByUserId));
        WorkSetId = workSetId; RepositoryContextId = repositoryContextId; StorageKey = RepositoryEntityValues.Required(storageKey, 200, nameof(storageKey));
        BaseBranch = RepositoryEntityValues.Required(baseBranch, 255, nameof(baseBranch)); BaseCommitSha = RepositoryEntityValues.Sha(baseCommitSha, nameof(baseCommitSha));
        WorkBranch = RepositoryEntityValues.Required(workBranch, 255, nameof(workBranch)); RemoteTargetBranch = RepositoryEntityValues.Optional(remoteTargetBranch, 255);
        State = RepositoryWorkspaceStates.Preparing; CreatedByUserId = createdByUserId; UpdatedByUserId = createdByUserId;
        AgentAccessGrantId = agentAccessGrantId; ChangeManagementActorId = changeManagementActorId; CreatedAtUtc = createdAtUtc; UpdatedAtUtc = createdAtUtc;
    }
    public Guid WorkSetId { get; private set; }
    public Guid RepositoryContextId { get; private set; }
    public string StorageKey { get; private set; } = string.Empty;
    public string BaseBranch { get; private set; } = string.Empty;
    public string BaseCommitSha { get; private set; } = string.Empty;
    public string WorkBranch { get; private set; } = string.Empty;
    public string? CurrentCommitSha { get; private set; }
    public string? LastPushedCommitSha { get; private set; }
    public string? RemoteTargetBranch { get; private set; }
    public string State { get; private set; } = RepositoryWorkspaceStates.Preparing;
    public DateTime? LastFetchedAtUtc { get; private set; }
    public DateTime? LastSyncedAtUtc { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public Guid UpdatedByUserId { get; private set; }
    public Guid? AgentAccessGrantId { get; private set; }
    public Guid? ChangeManagementActorId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public void MarkMaterialized(string currentCommitSha, DateTime fetchedAtUtc, Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        CurrentCommitSha = RepositoryEntityValues.Sha(currentCommitSha, nameof(currentCommitSha));
        State = RepositoryWorkspaceStates.Clean;
        LastFetchedAtUtc = fetchedAtUtc;
        LastSyncedAtUtc = changedAtUtc;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }
    public void ResetPreparing(Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        State = RepositoryWorkspaceStates.Preparing;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }
    public void MarkFailed(Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        State = RepositoryWorkspaceStates.Failed;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }
    public void MarkClosed(Guid actorUserId, DateTime changedAtUtc)
    {
        RepositoryEntityValues.GuidRequired(actorUserId, nameof(actorUserId));
        State = RepositoryWorkspaceStates.Closed;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }    public byte[] RowVersion { get; private set; } = [];
}

public sealed class RepositoryPullRequestLink : Entity
{
    private RepositoryPullRequestLink() { }
    public RepositoryPullRequestLink(Guid repositoryContextId, Guid workSetId, Guid workspaceId, string provider, string providerPullRequestId,
        int pullRequestNumber, string webUrl, string state, string baseRef, string headRef, string baseSha, string headSha, Guid createdByUserId, DateTime createdAtUtc)
    {
        RepositoryEntityValues.GuidRequired(repositoryContextId, nameof(repositoryContextId)); RepositoryEntityValues.GuidRequired(workSetId, nameof(workSetId)); RepositoryEntityValues.GuidRequired(workspaceId, nameof(workspaceId)); RepositoryEntityValues.GuidRequired(createdByUserId, nameof(createdByUserId));
        if(pullRequestNumber < 1) throw new ArgumentOutOfRangeException(nameof(pullRequestNumber));
        RepositoryContextId = repositoryContextId; WorkSetId = workSetId; WorkspaceId = workspaceId; Provider = RepositoryEntityValues.Required(provider, 30, nameof(provider));
        ProviderPullRequestId = RepositoryEntityValues.Required(providerPullRequestId, 100, nameof(providerPullRequestId)); PullRequestNumber = pullRequestNumber;
        WebUrl = RepositoryEntityValues.Required(webUrl, 500, nameof(webUrl)); State = RepositoryEntityValues.Required(state, 50, nameof(state));
        BaseRef = RepositoryEntityValues.Required(baseRef, 255, nameof(baseRef)); HeadRef = RepositoryEntityValues.Required(headRef, 255, nameof(headRef));
        BaseSha = RepositoryEntityValues.Sha(baseSha, nameof(baseSha)); HeadSha = RepositoryEntityValues.Sha(headSha, nameof(headSha)); LastSeenAtUtc = createdAtUtc;
        CreatedByUserId = createdByUserId; UpdatedByUserId = createdByUserId; CreatedAtUtc = createdAtUtc; UpdatedAtUtc = createdAtUtc;
    }
    public Guid RepositoryContextId { get; private set; }
    public Guid WorkSetId { get; private set; }
    public Guid WorkspaceId { get; private set; }
    public string Provider { get; private set; } = string.Empty;
    public string ProviderPullRequestId { get; private set; } = string.Empty;
    public int PullRequestNumber { get; private set; }
    public string WebUrl { get; private set; } = string.Empty;
    public string State { get; private set; } = string.Empty;
    public string BaseRef { get; private set; } = string.Empty;
    public string HeadRef { get; private set; } = string.Empty;
    public string BaseSha { get; private set; } = string.Empty;
    public string HeadSha { get; private set; } = string.Empty;
    public DateTime LastSeenAtUtc { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public Guid UpdatedByUserId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];
}

internal static class RepositoryEntityValues
{
    public static void GuidRequired(Guid value, string name) { if(value == Guid.Empty) throw new ArgumentException($"{name} is required.", name); }
    public static string Required(string value, int max, string name) { string normalized = value?.Trim() ?? string.Empty; if(normalized.Length == 0 || normalized.Length > max) throw new ArgumentException($"{name} is required and may not exceed {max} characters.", name); return normalized; }
    public static string? Optional(string? value, int max) { string? normalized = string.IsNullOrWhiteSpace(value) ? null : value.Trim(); if(normalized?.Length > max) throw new ArgumentException($"Value may not exceed {max} characters."); return normalized; }
    public static string Sha(string value, string name) { string normalized = Required(value, 64, name).ToLowerInvariant(); if(normalized.Length is not (40 or 64) || normalized.Any(c => !Uri.IsHexDigit(c))) throw new ArgumentException("Git SHA must be 40 or 64 hexadecimal characters.", name); return normalized; }
    public static string? OptionalSha(string? value, string name) => string.IsNullOrWhiteSpace(value) ? null : Sha(value, name);
}