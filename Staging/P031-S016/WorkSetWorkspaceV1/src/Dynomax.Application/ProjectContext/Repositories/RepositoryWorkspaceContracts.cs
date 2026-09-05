using Dynomax.Application.ProjectContext;

namespace Dynomax.Application.ProjectContext.Repositories;

public static class RepositoryWorkspaceErrorCodes
{
    public const string NotFound = "REPOSITORY_WORKSPACE_NOT_FOUND";
    public const string PolicyDenied = "REPOSITORY_WORKSPACE_POLICY_DENIED";
    public const string InvalidInput = "REPOSITORY_WORKSPACE_INVALID";
    public const string Conflict = "REPOSITORY_WORKSPACE_CONFLICT";
    public const string StaleBase = "REPOSITORY_WORKSPACE_STALE_BASE";
    public const string BaseRefNotFound = "REPOSITORY_WORKSPACE_BASE_REF_NOT_FOUND";
    public const string MaterializationFailed = "REPOSITORY_WORKSPACE_MATERIALIZATION_FAILED";
}

public sealed record CreateRepositoryWorkSetCommand(string Title, string Goal, Guid? LinkedProjectIssueId, Guid? LinkedProductChangeId, Guid? LinkedTestingStepId);
public sealed record AddRepositoryWorkspaceCommand(Guid ProjectEnvironmentId, string BaseBranch, string? ExpectedBaseCommitSha, string? RemoteTargetBranch);
public sealed record RebuildRepositoryWorkspaceCommand(Guid ProjectEnvironmentId, string? ExpectedBaseCommitSha);
public sealed record CloseRepositoryWorkSetCommand(string ExpectedConcurrencyToken);
public sealed record RepositoryWorkspaceSummary(Guid WorkspaceId, Guid RepositoryContextId, string RepositoryFullName, string BaseBranch, string BaseCommitSha, string WorkBranch, string? CurrentCommitSha, string? LastPushedCommitSha, string? RemoteTargetBranch, string State, DateTime? LastFetchedAtUtc, DateTime? LastSyncedAtUtc, string ConcurrencyToken);
public sealed record RepositoryWorkSetSummary(Guid WorkSetId, string Title, string Goal, string Status, Guid OwnerUserId, Guid? LinkedProjectIssueId, Guid? LinkedProductChangeId, Guid? LinkedTestingStepId, DateTime CreatedAtUtc, DateTime UpdatedAtUtc, DateTime? ExpiresAtUtc, string ConcurrencyToken, IReadOnlyList<RepositoryWorkspaceSummary> Workspaces);
public sealed record AddRepositoryWorkspaceResult(RepositoryWorkSetSummary WorkSet, RepositoryWorkspaceSummary Workspace, bool Created, bool Materialized, bool Rebuilt);

public sealed class RepositoryWorkspaceException : InvalidOperationException
{
    public RepositoryWorkspaceException(string code, string message) : base(message) { Code = code; }
    public string Code { get; }
}

public interface IRepositoryWorkspaceService
{
    Task<IReadOnlyList<RepositoryWorkSetSummary>> ListAsync(ProjectContextRequestAccess access, bool includeClosed, CancellationToken cancellationToken = default);
    Task<RepositoryWorkSetSummary> GetAsync(ProjectContextRequestAccess access, Guid workSetId, CancellationToken cancellationToken = default);
    Task<RepositoryWorkSetSummary> CreateAsync(ProjectContextRequestAccess access, CreateRepositoryWorkSetCommand command, CancellationToken cancellationToken = default);
    Task<AddRepositoryWorkspaceResult> AddRepositoryAsync(ProjectContextRequestAccess access, Guid workSetId, Guid repositoryContextId, AddRepositoryWorkspaceCommand command, CancellationToken cancellationToken = default);
    Task<AddRepositoryWorkspaceResult> RebuildAsync(ProjectContextRequestAccess access, Guid workSetId, Guid repositoryContextId, RebuildRepositoryWorkspaceCommand command, CancellationToken cancellationToken = default);
    Task<RepositoryWorkSetSummary> CloseAsync(ProjectContextRequestAccess access, Guid workSetId, CloseRepositoryWorkSetCommand command, CancellationToken cancellationToken = default);
}