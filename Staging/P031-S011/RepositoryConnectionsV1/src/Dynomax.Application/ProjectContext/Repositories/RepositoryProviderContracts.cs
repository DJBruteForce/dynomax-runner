namespace Dynomax.Application.ProjectContext.Repositories;

public static class RepositoryCapabilityStates
{
    public const string Available = "Available";
    public const string Denied = "Denied";
    public const string Unavailable = "Unavailable";
    public const string Unproven = "Unproven";
}
public static class RepositoryProviderErrorCodes
{
    public const string InvalidRepositoryIdentity = "GITHUB_INVALID_REPOSITORY_IDENTITY";
    public const string AuthenticationFailed = "GITHUB_AUTHENTICATION_FAILED";
    public const string PermissionDenied = "GITHUB_PERMISSION_DENIED";
    public const string RepositoryNotFound = "GITHUB_REPOSITORY_NOT_FOUND";
    public const string SsoAuthorizationRequired = "GITHUB_SSO_AUTHORIZATION_REQUIRED";
    public const string RateLimited = "GITHUB_RATE_LIMITED";
    public const string ProviderUnavailable = "GITHUB_PROVIDER_UNAVAILABLE";
    public const string NetworkError = "GITHUB_NETWORK_ERROR";
    public const string InvalidResponse = "GITHUB_INVALID_RESPONSE";
    public const string ProviderError = "GITHUB_PROVIDER_ERROR";
}
public sealed record RepositoryProviderIdentity(string Owner, string Name, string FullName, string WebUrl, string CloneUrl);
public sealed record RepositoryRateLimitSnapshot(long? Limit, long? Remaining, DateTimeOffset? ResetAtUtc, int? RetryAfterSeconds);
public sealed record RepositoryCapabilitySnapshot(string MetadataRead, string ContentsRead, string PullRequestsRead, string ActionsRead, string CommitStatusesRead, string BranchRulesRead, string ContentsWrite, string PullRequestsWrite, string WorkflowsWrite, bool? UserCanPush);
public sealed record RepositoryBranchRulesSnapshot(bool? Protected, bool RulesReadable, int ActiveRuleCount);
public sealed record RepositoryProviderRepository(string ProviderRepositoryId, string Owner, string Name, string FullName, string WebUrl, string CloneUrl, string Visibility, bool IsArchived, bool IsDisabled, bool? IsFork, string? Description, string? DefaultBranch, string? DefaultBranchHeadSha, string? DefaultTreeSha, bool IsEmpty, RepositoryCapabilitySnapshot Capabilities, RepositoryBranchRulesSnapshot BranchRules, RepositoryRateLimitSnapshot RateLimit);
public sealed record RepositoryProviderDiscoveryResult(string Provider, string AuthenticatedLogin, IReadOnlyList<RepositoryProviderRepository> Repositories, RepositoryRateLimitSnapshot RateLimit);
public sealed class RepositoryProviderException : InvalidOperationException
{
    public RepositoryProviderException(string code, string message, int? httpStatusCode = null, DateTimeOffset? retryAtUtc = null) : base(message) { Code = code; HttpStatusCode = httpStatusCode; RetryAtUtc = retryAtUtc; }
    public string Code { get; }
    public int? HttpStatusCode { get; }
    public DateTimeOffset? RetryAtUtc { get; }
}
public interface IRepositoryProviderClient
{
    string Provider { get; }
    RepositoryProviderIdentity CanonicalizeReference(string value);
    Task<RepositoryProviderDiscoveryResult> DiscoverAccessibleRepositoriesAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, int maxRepositories = 100, CancellationToken cancellationToken = default);
    Task<RepositoryProviderRepository> DiscoverRepositoryAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, CancellationToken cancellationToken = default);
}