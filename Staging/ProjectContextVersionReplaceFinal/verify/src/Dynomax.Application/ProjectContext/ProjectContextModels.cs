namespace Dynomax.Application.ProjectContext;

public static class ProjectContextLimits
{
    public const long MaxUploadBytes = 200L * 1024 * 1024;
    public const int MaxFilesPerUpload = 20;
    public const int MaxRetainedVersionsPerResource = 3;
    public const long MaxRequestBytes = (MaxUploadBytes * MaxFilesPerUpload) + (10L * 1024 * 1024);
    public const long MaxAgentBinaryTransferBytes = 8L * 1024 * 1024;
    public const int MaxAgentBinarySegmentBytes = 2 * 1024 * 1024;
    public const int MaxArchiveEntries = 10_000;
    public const long MaxArchiveUncompressedBytes = 512L * 1024 * 1024;
    public const long MaxSingleArchiveEntryBytes = 32L * 1024 * 1024;
    public const double MaxCompressionRatio = 200d;
    public const int MaxArchivePathLength = 1024;
    public const int MaxArchiveDepth = 64;
    public const int MaxInlineTextCharacters = 200_000;
    public const int MaxArchiveListTake = 500;
    public const int MaxResourceListTake = 200;
}

public sealed record ProjectContextRequestAccess(
    Guid ProjectId,
    Guid ActorUserId,
    bool CanRead,
    bool CanUpload,
    bool CanManage,
    bool CanDelete,
    bool EnforceAgentReadable,
    Guid? AgentGrantId = null);

public sealed record ProjectContextCapabilities(
    bool ProjectContextEnabled,
    IReadOnlyList<string> SourceTypes,
    IReadOnlyList<string> RetrievalModes,
    IReadOnlyList<string> ArchiveFormats,
    bool SupportsImmutableVersions,
    bool SupportsCurrentPointer,
    int MaxRetainedVersionsPerResource,
    string HashAlgorithm,
    long MaxUploadBytes,
    long MaxAgentBinaryTransferBytes,
    int MaxAgentBinarySegmentBytes,
    int MaxInlineTextCharacters,
    int MaxArchiveEntries,
    long MaxArchiveUncompressedBytes,
    long MaxSingleArchiveEntryBytes,
    double MaxCompressionRatio,
    int MaxArchivePathLength,
    bool BinaryResourceTransferSupported,
    bool SegmentedBinaryTransferSupported,
    bool ArchiveBrowsingSupported,
    bool FolderSnapshotBrowsingSupported,
    bool CanRead,
    bool CanUpload,
    bool CanManage,
    bool CanDelete);

public sealed record ProjectContextSourceSummary(
    Guid SourceId,
    Guid ProjectId,
    string SourceType,
    string DisplayName,
    string? Description,
    bool IsActive,
    bool AgentReadable,
    int ResourceCount,
    int CurrentResourceCount,
    DateTime UpdatedAtUtc);

public sealed record ProjectContextResourceSummary(
    Guid ResourceId,
    Guid SourceId,
    string LogicalKey,
    string DisplayName,
    string? Category,
    string? Description,
    IReadOnlyList<string> Tags,
    bool IsAuthoritative,
    bool IsActive,
    Guid? CurrentVersionId,
    int? CurrentVersionNumber,
    string? FileName,
    string? LogicalPath,
    string? ContentType,
    long? SizeBytes,
    string? Sha256,
    bool? AgentReadable,
    string? Classification,
    string? ArchiveType,
    int? ArchiveEntryCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record ProjectContextVersionSummary(
    Guid ResourceVersionId,
    Guid ResourceId,
    int VersionNumber,
    string OriginalFileName,
    string LogicalPath,
    string ContentType,
    long SizeBytes,
    string Sha256,
    bool IsCurrent,
    bool AgentReadable,
    string Classification,
    string? ArchiveType,
    int? ArchiveEntryCount,
    DateTime CreatedAtUtc,
    Guid? SupersedesVersionId);

public sealed record ProjectContextResourceDetails(
    ProjectContextResourceSummary Resource,
    IReadOnlyList<ProjectContextVersionSummary> Versions);

public sealed record UploadProjectContextFileCommand(
    Guid ProjectId,
    string FileName,
    string ContentType,
    byte[] Content,
    string? LogicalName,
    string? Category,
    string? Description,
    IReadOnlyList<string> Tags,
    bool MarkCurrent,
    bool AgentReadable,
    bool IsAuthoritative,
    Guid ActorUserId,
    DateTime UploadedAtUtc,
    bool IsTrustedFolderSnapshot = false,
    Guid? TargetResourceId = null,
    Guid? ExpectedCurrentVersionId = null,
    DateTime? ClientLastModifiedUtc = null,
    bool AllowOlderFile = false);

public sealed record ImportProjectContextFolderCommand(
    Guid ProjectId,
    string FolderPath,
    string? LogicalName,
    string? Category,
    string? Description,
    IReadOnlyList<string> Tags,
    bool MarkCurrent,
    bool AgentReadable,
    bool IsAuthoritative,
    bool ExcludeGeneratedDirectories,
    Guid ActorUserId,
    DateTime ImportedAtUtc);

public sealed record ImportProjectContextFolderResult(
    UploadProjectContextFileResult Upload,
    string SnapshotFileName,
    int FileCount,
    long SourceBytes);

public sealed record UploadProjectContextFileResult(
    Guid SourceId,
    Guid ResourceId,
    Guid ResourceVersionId,
    int VersionNumber,
    bool IsCurrent,
    string Sha256,
    long SizeBytes,
    string? ArchiveType,
    int? ArchiveEntryCount);

public sealed record ProjectContextResourceQuery(
    Guid ProjectId,
    Guid? SourceId,
    string? SourceType,
    string? Search,
    string? LogicalPathPrefix,
    string? Category,
    bool CurrentOnly,
    bool IncludeSuperseded,
    bool IncludeInactive,
    int Skip,
    int Take);

public sealed record ProjectContextResourcePage(
    int Skip,
    int Take,
    int Total,
    IReadOnlyList<ProjectContextResourceSummary> Items);

public static class ProjectContextVersionSelectors
{
    public const string Current = "Current";
    public const string LatestVersion = "LatestVersion";
    public const string ExactVersion = "ExactVersion";
    public const string ExactResourceVersionId = "ExactResourceVersionId";
    public const string ExactSha256 = "ExactSha256";
}

public sealed record ResolveProjectContextResourceRequest(
    Guid ProjectId,
    Guid? ResourceId,
    string? LogicalKey,
    string Selector,
    int? VersionNumber,
    Guid? ResourceVersionId,
    string? Sha256);

public sealed record ProjectContextTextResult(
    Guid ResourceVersionId,
    string FileName,
    string ContentType,
    string Sha256,
    long SizeBytes,
    string Encoding,
    int ReturnedOffset,
    int ReturnedCharacters,
    bool HasMore,
    string Content);

public sealed record ProjectContextBinaryResult(
    Guid ResourceId,
    Guid ResourceVersionId,
    string FileName,
    string ContentType,
    byte[] Content,
    string Sha256,
    long SizeBytes,
    string Classification);

public sealed record ProjectContextBinarySegmentResult(
    Guid ResourceId,
    Guid ResourceVersionId,
    string FileName,
    string ContentType,
    byte[] Content,
    string SegmentSha256,
    long Offset,
    int ReturnedBytes,
    bool HasMore,
    string ResourceSha256,
    long ResourceSizeBytes,
    string Classification);

public sealed record ProjectContextArchiveEntrySummary(
    Guid ResourceVersionId,
    string CanonicalPath,
    long UncompressedBytes,
    long CompressedBytes,
    string ContentType,
    bool IsDirectory,
    bool IsText,
    string? Sha256);

public sealed record ProjectContextArchiveEntryPage(
    int Skip,
    int Take,
    int Total,
    IReadOnlyList<ProjectContextArchiveEntrySummary> Items);

public sealed record ProjectContextArchiveEntryResult(
    Guid ResourceVersionId,
    string CanonicalPath,
    string ContentType,
    byte[] Content,
    string Sha256,
    long SizeBytes,
    bool IsText,
    string Classification);
