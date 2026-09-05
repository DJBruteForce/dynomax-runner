using Dynomax.Application.ProjectContext;

namespace Dynomax.Application.ProjectContext.Repositories;

public static class RepositoryHistoryErrorCodes
{
    public const string NotFound = "REPOSITORY_HISTORY_NOT_FOUND";
    public const string PolicyDenied = "REPOSITORY_HISTORY_POLICY_DENIED";
    public const string InvalidRef = "REPOSITORY_HISTORY_INVALID_REF";
    public const string InvalidCommit = "REPOSITORY_HISTORY_INVALID_COMMIT";
    public const string InvalidPath = "REPOSITORY_HISTORY_INVALID_PATH";
    public const string InvalidPaging = "REPOSITORY_HISTORY_INVALID_PAGING";
    public const string TooLarge = "REPOSITORY_HISTORY_TOO_LARGE";
    public const string EmptyRepository = "REPOSITORY_HISTORY_EMPTY_REPOSITORY";
}

public static class RepositoryHistoryLimits
{
    public const int MaxPageSize = 100;
    public const int MaxCompareFiles = 300;
    public const int MaxCompareCommits = 250;
    public const int MaxPatchCharactersPerFile = 100000;
    public const int MaxUnifiedDiffCharacters = 1000000;
    public const int MaxBlameRanges = 5000;
    public const int MaxBlameLines = 50000;
}

public sealed class RepositoryHistoryException : InvalidOperationException
{
    public RepositoryHistoryException(string code, string message) : base(message) => Code = code;
    public string Code { get; }
}

public sealed record RepositoryRuleSummary(bool Available, bool RequiresPullRequest, bool RequiresStatusChecks, bool RequiresLinearHistory, bool BlocksForcePush, bool BlocksDeletion, IReadOnlyList<string> RequiredStatusChecks);
public sealed record RepositoryBranchSummary(string Name, string CommitSha, bool Protected, bool IsDefault, bool IsStoredDefaultHeadStale);
public sealed record RepositoryBranchDetail(string Name, string CommitSha, bool Protected, bool IsDefault, bool IsStoredDefaultHeadStale, RepositoryRuleSummary Rules);
public sealed record RepositoryTagSummary(string Name, string CommitSha);
public sealed record RepositoryResolvedRef(string RefType, string Name, string CommitSha, bool Mutable);
public sealed record RepositoryCommitSummary(string Sha, string MessageHeadline, DateTimeOffset? CommittedAtUtc, string? AuthorName, string? AuthorEmail, IReadOnlyList<string> ParentShas);
public sealed record RepositoryCommitFile(string Path, string Status, int Additions, int Deletions, int Changes, string? PreviousPath, string? Patch, bool PatchTruncated);
public sealed record RepositoryCommitDetail(string Sha, string Message, DateTimeOffset? CommittedAtUtc, string? AuthorName, string? AuthorEmail, IReadOnlyList<string> ParentShas, int Additions, int Deletions, int TotalChanges, IReadOnlyList<RepositoryCommitFile> Files, bool FilesTruncated);
public sealed record RepositoryCommitPage(Guid RepositoryContextId, string FullName, string CommitSha, string? Path, int Page, int PageSize, bool HasMore, IReadOnlyList<RepositoryCommitSummary> Commits);
public sealed record RepositoryCompareResult(Guid RepositoryContextId, string FullName, string BaseSha, string HeadSha, string Status, int AheadBy, int BehindBy, int TotalCommits, IReadOnlyList<RepositoryCommitSummary> Commits, IReadOnlyList<RepositoryCommitFile> Files, bool CommitsTruncated, bool FilesTruncated, string UnifiedDiff, bool UnifiedDiffTruncated);
public sealed record RepositoryBlameRange(int StartingLine, int EndingLine, string CommitSha, string MessageHeadline, DateTimeOffset? CommittedAtUtc, string? AuthorName, string? AuthorEmail);
public sealed record RepositoryBlameResult(Guid RepositoryContextId, string FullName, string CommitSha, string Path, int TotalRanges, int TotalLines, bool Truncated, IReadOnlyList<RepositoryBlameRange> Ranges);

public sealed record RepositoryProviderBranch(string Name, string CommitSha, bool Protected);
public sealed record RepositoryProviderBranchDetail(string Name, string CommitSha, bool Protected, RepositoryRuleSummary Rules);
public sealed record RepositoryProviderTag(string Name, string CommitSha);
public sealed record RepositoryProviderCommit(string Sha, string Message, DateTimeOffset? CommittedAtUtc, string? AuthorName, string? AuthorEmail, IReadOnlyList<string> ParentShas, int Additions, int Deletions, int TotalChanges, IReadOnlyList<RepositoryCommitFile> Files, bool FilesTruncated);
public sealed record RepositoryProviderCompare(string BaseSha, string HeadSha, string Status, int AheadBy, int BehindBy, int TotalCommits, IReadOnlyList<RepositoryProviderCommit> Commits, IReadOnlyList<RepositoryCommitFile> Files, bool CommitsTruncated, bool FilesTruncated, string UnifiedDiff, bool UnifiedDiffTruncated);
public sealed record RepositoryProviderBlame(IReadOnlyList<RepositoryBlameRange> Ranges, bool Truncated);

public interface IRepositoryHistoryProviderClient
{
    Task<IReadOnlyList<RepositoryProviderBranch>> ListBranchesAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<RepositoryProviderBranchDetail> GetBranchAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string branch, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RepositoryProviderTag>> ListTagsAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RepositoryProviderCommit>> ListCommitsAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string exactCommitSha, string? path, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<RepositoryProviderCommit> GetCommitAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string exactCommitSha, CancellationToken cancellationToken = default);
    Task<RepositoryProviderCompare> CompareAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string baseSha, string headSha, CancellationToken cancellationToken = default);
    Task<RepositoryProviderBlame> GetBlameAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string exactCommitSha, string path, CancellationToken cancellationToken = default);
}

public interface IRepositoryHistoryService
{
    Task<IReadOnlyList<RepositoryBranchSummary>> ListBranchesAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<RepositoryBranchDetail?> GetBranchAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string branch, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RepositoryTagSummary>> ListTagsAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<RepositoryResolvedRef?> ResolveRefAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string refType, string value, CancellationToken cancellationToken = default);
    Task<RepositoryCommitPage> ListCommitsAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string? path, int page, int pageSize, CancellationToken cancellationToken = default);
    Task<RepositoryCommitDetail?> GetCommitAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, CancellationToken cancellationToken = default);
    Task<RepositoryCompareResult?> CompareAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? baseSha, string? headSha, CancellationToken cancellationToken = default);
    Task<RepositoryBlameResult?> GetBlameAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, CancellationToken cancellationToken = default);
}