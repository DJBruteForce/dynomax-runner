using Dynomax.Domain.Common;

namespace Dynomax.Domain.ProjectContext;

public static class ProjectContextSourceTypes
{
    public const string UploadedFiles = "UploadedFiles";
    public const string GitRepositories = "GitRepositories";
}

public static class ProjectContextArchiveTypes
{
    public const string Zip = "zip";
}

public sealed class ProjectContextSource : Entity
{
    private ProjectContextSource() { }

    public ProjectContextSource(Guid projectId, string sourceType, string displayName, string? description, bool isAgentReadable, Guid createdByUserId, DateTime createdAtUtc)
    {
        if (projectId == Guid.Empty) throw new ArgumentException("Project ID is required.", nameof(projectId));
        if (createdByUserId == Guid.Empty) throw new ArgumentException("Created-by user ID is required.", nameof(createdByUserId));
        ProjectId = projectId;
        SourceType = Required(sourceType, 50, nameof(sourceType));
        DisplayName = Required(displayName, 150, nameof(displayName));
        Description = Optional(description, 1000);
        IsActive = true;
        IsAgentReadable = isAgentReadable;
        CreatedByUserId = createdByUserId;
        UpdatedByUserId = createdByUserId;
        CreatedAtUtc = createdAtUtc;
        UpdatedAtUtc = createdAtUtc;
    }

    public Guid ProjectId { get; private set; }
    public string SourceType { get; private set; } = string.Empty;
    public string DisplayName { get; private set; } = string.Empty;
    public string? Description { get; private set; }
    public bool IsActive { get; private set; }
    public bool IsAgentReadable { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public Guid UpdatedByUserId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public void SetActive(bool active, Guid actorUserId, DateTime changedAtUtc)
    {
        IsActive = active;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }

    private static string Required(string value, int max, string name)
    {
        string normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length == 0 || normalized.Length > max) throw new ArgumentException($"{name} is required and may not exceed {max} characters.", name);
        return normalized;
    }
    private static string? Optional(string? value, int max)
    {
        string? normalized = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        if (normalized?.Length > max) throw new ArgumentException($"Value may not exceed {max} characters.");
        return normalized;
    }
}

public sealed class ProjectContextResource : Entity
{
    private ProjectContextResource() { }

    public ProjectContextResource(Guid sourceId, string logicalKey, string displayName, string? category, string? description, string tagsJson,
        bool isAuthoritative, Guid createdByUserId, DateTime createdAtUtc)
    {
        if (sourceId == Guid.Empty) throw new ArgumentException("Source ID is required.", nameof(sourceId));
        SourceId = sourceId;
        LogicalKey = Required(logicalKey, 300, nameof(logicalKey));
        DisplayName = Required(displayName, 260, nameof(displayName));
        Category = Optional(category, 100);
        Description = Optional(description, 2000);
        TagsJson = string.IsNullOrWhiteSpace(tagsJson) ? "[]" : tagsJson;
        IsAuthoritative = isAuthoritative;
        IsActive = true;
        CreatedByUserId = createdByUserId;
        UpdatedByUserId = createdByUserId;
        CreatedAtUtc = createdAtUtc;
        UpdatedAtUtc = createdAtUtc;
    }

    public Guid SourceId { get; private set; }
    public string LogicalKey { get; private set; } = string.Empty;
    public string DisplayName { get; private set; } = string.Empty;
    public string? Category { get; private set; }
    public string? Description { get; private set; }
    public string TagsJson { get; private set; } = "[]";
    public Guid? CurrentVersionId { get; private set; }
    public bool IsAuthoritative { get; private set; }
    public bool IsActive { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public Guid UpdatedByUserId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public DateTime UpdatedAtUtc { get; private set; }
    public byte[] RowVersion { get; private set; } = [];

    public void UpdateMetadata(string displayName, string? category, string? description, string tagsJson, bool isAuthoritative, Guid actorUserId, DateTime changedAtUtc)
    {
        DisplayName = Required(displayName, 260, nameof(displayName));
        Category = Optional(category, 100);
        Description = Optional(description, 2000);
        TagsJson = string.IsNullOrWhiteSpace(tagsJson) ? "[]" : tagsJson;
        IsAuthoritative = isAuthoritative;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }

    public void SetCurrent(Guid versionId, Guid actorUserId, DateTime changedAtUtc)
    {
        if (versionId == Guid.Empty) throw new ArgumentException("Version ID is required.", nameof(versionId));
        CurrentVersionId = versionId;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }

    public void Retire(Guid actorUserId, DateTime changedAtUtc)
    {
        IsActive = false;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }

    public void Restore(Guid actorUserId, DateTime changedAtUtc)
    {
        IsActive = true;
        UpdatedByUserId = actorUserId;
        UpdatedAtUtc = changedAtUtc;
    }

    private static string Required(string value, int max, string name)
    {
        string normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length == 0 || normalized.Length > max) throw new ArgumentException($"{name} is required and may not exceed {max} characters.", name);
        return normalized;
    }
    private static string? Optional(string? value, int max)
    {
        string? normalized = string.IsNullOrWhiteSpace(value) ? null : value.Trim();
        if (normalized?.Length > max) throw new ArgumentException($"Value may not exceed {max} characters.");
        return normalized;
    }
}

public sealed class ProjectContextResourceVersion : Entity
{
    private ProjectContextResourceVersion() { }

    public ProjectContextResourceVersion(Guid resourceId, int versionNumber, string originalFileName, string logicalPath, string contentType,
        long sizeBytes, string sha256, Guid agentArtifactId, bool agentReadable, string classification, string? archiveType,
        int? archiveEntryCount, Guid createdByUserId, DateTime createdAtUtc, Guid? supersedesVersionId)
    {
        if (resourceId == Guid.Empty) throw new ArgumentException("Resource ID is required.", nameof(resourceId));
        if (versionNumber < 1) throw new ArgumentOutOfRangeException(nameof(versionNumber));
        if (sizeBytes < 0) throw new ArgumentOutOfRangeException(nameof(sizeBytes));
        if (agentArtifactId == Guid.Empty) throw new ArgumentException("Artifact ID is required.", nameof(agentArtifactId));
        string normalizedHash = sha256?.Trim().ToLowerInvariant() ?? string.Empty;
        if (normalizedHash.Length != 64 || normalizedHash.Any(c => !Uri.IsHexDigit(c))) throw new ArgumentException("SHA-256 must be a 64-character hexadecimal value.", nameof(sha256));
        ResourceId = resourceId;
        VersionNumber = versionNumber;
        OriginalFileName = Required(originalFileName, 260, nameof(originalFileName));
        LogicalPath = Required(logicalPath, 500, nameof(logicalPath));
        ContentType = Required(contentType, 150, nameof(contentType));
        SizeBytes = sizeBytes;
        Sha256 = normalizedHash;
        AgentArtifactId = agentArtifactId;
        AgentReadable = agentReadable;
        Classification = Required(classification, 50, nameof(classification));
        ArchiveType = string.IsNullOrWhiteSpace(archiveType) ? null : archiveType.Trim().ToLowerInvariant();
        ArchiveEntryCount = archiveEntryCount;
        CreatedByUserId = createdByUserId;
        CreatedAtUtc = createdAtUtc;
        SupersedesVersionId = supersedesVersionId;
    }

    public Guid ResourceId { get; private set; }
    public int VersionNumber { get; private set; }
    public string OriginalFileName { get; private set; } = string.Empty;
    public string LogicalPath { get; private set; } = string.Empty;
    public string ContentType { get; private set; } = string.Empty;
    public long SizeBytes { get; private set; }
    public string Sha256 { get; private set; } = string.Empty;
    public Guid AgentArtifactId { get; private set; }
    public bool AgentReadable { get; private set; }
    public string Classification { get; private set; } = string.Empty;
    public string? ArchiveType { get; private set; }
    public int? ArchiveEntryCount { get; private set; }
    public Guid CreatedByUserId { get; private set; }
    public DateTime CreatedAtUtc { get; private set; }
    public Guid? SupersedesVersionId { get; private set; }

    public void ClearSupersedesVersion()
    {
        SupersedesVersionId = null;
    }

    private static string Required(string value, int max, string name)
    {
        string normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length == 0 || normalized.Length > max) throw new ArgumentException($"{name} is required and may not exceed {max} characters.", name);
        return normalized;
    }
}

public sealed class ProjectContextArchiveEntry : Entity
{
    private ProjectContextArchiveEntry() { }

    public ProjectContextArchiveEntry(Guid resourceVersionId, string canonicalPath, string originalPath, bool isDirectory,
        long uncompressedBytes, long compressedBytes, string contentType, bool isText, string? sha256)
    {
        if (resourceVersionId == Guid.Empty) throw new ArgumentException("Resource version ID is required.", nameof(resourceVersionId));
        ResourceVersionId = resourceVersionId;
        CanonicalPath = Required(canonicalPath, 1024, nameof(canonicalPath));
        OriginalPath = Required(originalPath, 1024, nameof(originalPath));
        IsDirectory = isDirectory;
        UncompressedBytes = uncompressedBytes;
        CompressedBytes = compressedBytes;
        ContentType = Required(contentType, 150, nameof(contentType));
        IsText = isText;
        Sha256 = string.IsNullOrWhiteSpace(sha256) ? null : sha256.Trim().ToLowerInvariant();
    }

    public Guid ResourceVersionId { get; private set; }
    public string CanonicalPath { get; private set; } = string.Empty;
    public string OriginalPath { get; private set; } = string.Empty;
    public bool IsDirectory { get; private set; }
    public long UncompressedBytes { get; private set; }
    public long CompressedBytes { get; private set; }
    public string ContentType { get; private set; } = string.Empty;
    public bool IsText { get; private set; }
    public string? Sha256 { get; private set; }

    private static string Required(string value, int max, string name)
    {
        string normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length == 0 || normalized.Length > max) throw new ArgumentException($"{name} is required and may not exceed {max} characters.", name);
        return normalized;
    }
}
