using Dynomax.Application.ProjectContext;
namespace Dynomax.Application.ProjectContext.Repositories;

public static class RepositoryConnectionHealthStates
{
    public const string Unknown = "Unknown"; public const string Healthy = "Healthy"; public const string Empty = "Empty"; public const string Error = "Error"; public const string Disconnected = "Disconnected";
}
public static class RepositoryConnectionErrorCodes
{
    public const string NotFound = "REPOSITORY_CONNECTION_NOT_FOUND"; public const string Duplicate = "REPOSITORY_CONNECTION_DUPLICATE"; public const string ConcurrencyConflict = "REPOSITORY_CONNECTION_CONCURRENCY"; public const string InvalidInput = "REPOSITORY_CONNECTION_INVALID"; public const string InvalidPolicy = "REPOSITORY_POLICY_INVALID";
}
public sealed record RepositoryPolicySnapshot(bool AllowRead,bool AllowWorkspace,bool AllowCommitPush,bool AllowPullRequest,bool AllowMerge,bool AllowRemoteBranchDelete,bool AllowActionsRerun,bool AllowDirectDefaultBranchWrite,bool AllowForcePush,bool RequirePullRequestForDefaultBranch,IReadOnlyList<string> AllowedTargetBranchPatterns,IReadOnlyList<string> AllowedBaseBranchPatterns,string AgentBranchPrefix);
public sealed record RepositoryConnectionSummary(Guid RepositoryContextId,Guid SourceId,string Provider,string ProviderRepositoryId,string Owner,string Name,string FullName,string WebUrl,string CloneUrl,string Visibility,bool IsArchived,bool IsDisabled,bool? IsFork,string? Description,string? Role,string? Purpose,IReadOnlyList<string> Tags,string? DefaultBranch,string? DefaultBranchHeadSha,string? DefaultTreeSha,Guid CredentialSecretReferenceId,string HealthStatus,string? LastErrorCode,DateTime? LastValidatedAtUtc,DateTime? LastRefreshedAtUtc,bool IsActive,string ConcurrencyToken,RepositoryPolicySnapshot Policy);
public sealed record RepositoryValidationResult(string Provider,string ProviderRepositoryId,string Owner,string Name,string FullName,string WebUrl,string CloneUrl,string Visibility,bool IsArchived,bool IsDisabled,bool? IsFork,string? Description,bool IsEmpty,string? DefaultBranch,string? DefaultBranchHeadSha,string? DefaultTreeSha,RepositoryCapabilitySnapshot Capabilities,RepositoryBranchRulesSnapshot BranchRules,RepositoryRateLimitSnapshot RateLimit);
public sealed record ConnectRepositoryCommand(Guid ProjectEnvironmentId,string RepositoryUrl,Guid CredentialSecretReferenceId,string? Role,string? Purpose,IReadOnlyList<string> Tags);
public sealed record ConnectRepositoryResult(RepositoryConnectionSummary Connection,bool Created,bool Reactivated,bool AlreadyConnected);
public sealed record RepositoryPolicyUpdate(bool AllowRead,bool AllowWorkspace,bool AllowCommitPush,bool AllowPullRequest,bool AllowMerge,bool AllowRemoteBranchDelete,bool AllowActionsRerun,bool AllowDirectDefaultBranchWrite,bool AllowForcePush,bool RequirePullRequestForDefaultBranch,IReadOnlyList<string> AllowedTargetBranchPatterns,IReadOnlyList<string> AllowedBaseBranchPatterns,string AgentBranchPrefix);
public sealed record UpdateRepositoryConnectionCommand(Guid ProjectEnvironmentId,Guid? CredentialSecretReferenceId,string? Role,string? Purpose,IReadOnlyList<string> Tags,RepositoryPolicyUpdate Policy,string ExpectedConcurrencyToken);
public sealed class RepositoryConnectionException : InvalidOperationException { public RepositoryConnectionException(string code,string message):base(message){Code=code;} public string Code{get;} }
public interface IRepositoryConnectionService
{
 Task<IReadOnlyList<RepositoryConnectionSummary>> ListAsync(ProjectContextRequestAccess access,bool includeInactive,CancellationToken cancellationToken=default);
 Task<RepositoryConnectionSummary> GetAsync(ProjectContextRequestAccess access,Guid repositoryContextId,CancellationToken cancellationToken=default);
 Task<RepositoryValidationResult> ValidateAsync(ProjectContextRequestAccess access,Guid projectEnvironmentId,string repositoryUrl,Guid credentialSecretReferenceId,CancellationToken cancellationToken=default);
 Task<ConnectRepositoryResult> ConnectAsync(ProjectContextRequestAccess access,ConnectRepositoryCommand command,CancellationToken cancellationToken=default);
 Task<RepositoryConnectionSummary> RefreshAsync(ProjectContextRequestAccess access,Guid projectEnvironmentId,Guid repositoryContextId,CancellationToken cancellationToken=default);
 Task<IReadOnlyList<RepositoryConnectionSummary>> RefreshAllAsync(ProjectContextRequestAccess access,Guid projectEnvironmentId,CancellationToken cancellationToken=default);
 Task<RepositoryConnectionSummary> UpdateAsync(ProjectContextRequestAccess access,Guid repositoryContextId,UpdateRepositoryConnectionCommand command,CancellationToken cancellationToken=default);
 Task<RepositoryConnectionSummary> DisconnectAsync(ProjectContextRequestAccess access,Guid repositoryContextId,string expectedConcurrencyToken,CancellationToken cancellationToken=default);
}