using Dynomax.Application.ProjectContext;

namespace Dynomax.Application.ProjectContext.Repositories;

public static class RepositoryReadErrorCodes
{
    public const string NotFound = "REPOSITORY_READ_NOT_FOUND";
    public const string PolicyDenied = "REPOSITORY_READ_POLICY_DENIED";
    public const string InvalidCommit = "REPOSITORY_READ_INVALID_COMMIT";
    public const string InvalidPath = "REPOSITORY_READ_INVALID_PATH";
    public const string InvalidPaging = "REPOSITORY_READ_INVALID_PAGING";
    public const string TooLarge = "REPOSITORY_READ_TOO_LARGE";
    public const string BinaryFile = "REPOSITORY_READ_BINARY_FILE";
    public const string TextFileExpected = "REPOSITORY_READ_TEXT_FILE_EXPECTED";
    public const string SymlinkDenied = "REPOSITORY_READ_SYMLINK_DENIED";
    public const string UnsupportedObject = "REPOSITORY_READ_UNSUPPORTED_OBJECT";
}

public static class RepositoryReadContentKinds
{
    public const string Directory = "Directory";
    public const string File = "File";
    public const string Symlink = "Symlink";
    public const string Submodule = "Submodule";
    public const string Text = "Text";
    public const string Binary = "Binary";
    public const string Oversized = "Oversized";
}

public static class RepositoryReadLimits
{
    public const int MaxTreeEntries = 50000;
    public const int MaxTreePageSize = 1000;
    public const int MaxSearchRepositories = 20;
    public const int MaxSearchFilesPerRepository = 5000;
    public const int MaxSearchMatches = 200;
    public const int MaxSearchFileBytes = 1048576;
    public const int MaxTextBlobBytes = 5242880;
    public const int MaxBinaryBlobBytes = 10485760;
    public const int MaxTextCharacters = 200000;
    public const int MaxBinarySegmentBytes = 2097152;
}

public sealed class RepositoryReadException : InvalidOperationException
{
    public RepositoryReadException(string code, string message) : base(message) => Code = code;
    public string Code { get; }
}

public sealed record RepositoryProviderCommitTree(string CommitSha, string TreeSha);
public sealed record RepositoryProviderTreeEntry(string Path, string Mode, string Type, string Sha, long? Size);
public sealed record RepositoryProviderTree(string TreeSha, bool Truncated, IReadOnlyList<RepositoryProviderTreeEntry> Entries);
public sealed record RepositoryProviderBlob(string Sha, long Size, byte[] Content);

public interface IRepositoryReadProviderClient
{
    Task<RepositoryProviderCommitTree> GetCommitTreeAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string commitSha, CancellationToken cancellationToken = default);
    Task<RepositoryProviderTree> GetTreeAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string treeSha, CancellationToken cancellationToken = default);
    Task<RepositoryProviderBlob> GetBlobAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string blobSha, int maxBytes, CancellationToken cancellationToken = default);
}

public sealed record RepositoryTopologyEntry(Guid RepositoryContextId, string Provider, string FullName, string? Role, string? Purpose, IReadOnlyList<string> Tags, string HealthStatus, string? DefaultBranch, string? DefaultBranchHeadSha, string? DefaultTreeSha, bool AllowRead, bool IsEmpty);
public sealed record RepositoryReadTarget(Guid RepositoryContextId, string? CommitSha);
public sealed record RepositoryDirectorySummary(int DirectoryCount, int FileCount, int SymlinkCount, int SubmoduleCount, long TotalFileBytes);
public sealed record RepositoryTreeEntry(string Path, string Name, string ParentPath, string Kind, string Mode, string ObjectSha, long? Size, int Depth, bool IsSymlink);
public sealed record RepositoryTreePage(Guid RepositoryContextId, string FullName, string? CommitSha, string? RootTreeSha, string Prefix, int? MaxDepth, int TotalEntries, int Skip, int Take, bool HasMore, bool IsComplete, RepositoryDirectorySummary Summary, IReadOnlyList<RepositoryTreeEntry> Entries);
public sealed record RepositorySearchRequest(Guid ProjectEnvironmentId, IReadOnlyList<RepositoryReadTarget> Targets, string Query, string? PathPrefix, int MaxFilesPerRepository = 1000, int MaxMatches = 100, int ContextCharacters = 240);
public sealed record RepositorySearchMatch(Guid RepositoryContextId, string FullName, string CommitSha, string Path, string BlobSha, int LineNumber, string Snippet);
public sealed record RepositorySearchResult(string Query, int RepositoriesScanned, int FilesScanned, int BinaryFilesSkipped, bool Truncated, IReadOnlyList<RepositorySearchMatch> Matches);
public sealed record RepositoryFileMetadata(Guid RepositoryContextId, string FullName, string? CommitSha, string Path, string Kind, string Mode, string ObjectSha, long? Size, bool IsText, bool IsBinary, bool CanReadText, bool CanReadBinarySegment);
public sealed record RepositoryTextPage(Guid RepositoryContextId, string FullName, string CommitSha, string Path, string BlobSha, long BlobBytes, int TotalCharacters, int TotalLines, int? ReturnedOffset, int? ReturnedCharacters, int? ReturnedLineStart, int? ReturnedLineCount, bool HasMore, string Text);
public sealed record RepositoryBinarySegment(Guid RepositoryContextId, string FullName, string CommitSha, string Path, string BlobSha, long BlobBytes, long Offset, int ReturnedBytes, bool HasMore, string Base64);

public interface IRepositoryReadService
{
    Task<IReadOnlyList<RepositoryTopologyEntry>> GetTopologyAsync(ProjectContextRequestAccess access, CancellationToken cancellationToken = default);
    Task<RepositoryTreePage> GetTreeAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string? prefix, int? maxDepth, int skip, int take, CancellationToken cancellationToken = default);
    Task<RepositorySearchResult> SearchAsync(ProjectContextRequestAccess access, RepositorySearchRequest request, CancellationToken cancellationToken = default);
    Task<RepositoryFileMetadata> GetFileMetadataAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, CancellationToken cancellationToken = default);
    Task<RepositoryTextPage> ReadTextAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, long? offset, int? maxCharacters, int? lineStart, int? lineCount, CancellationToken cancellationToken = default);
    Task<RepositoryBinarySegment> ReadBinarySegmentAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, long offset, int maxBytes, CancellationToken cancellationToken = default);
}