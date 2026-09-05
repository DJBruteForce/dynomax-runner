using System.Data;
using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dynomax.Application.Auditing;
using Dynomax.Application.Automation;
using Dynomax.Application.ProjectContext;
using Dynomax.Domain.Automation;
using Dynomax.Domain.ProjectContext;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Dynomax.Infrastructure.ProjectContext;

internal sealed class ProjectContextService : IProjectContextService
{
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    private const string TemporaryExpiryTagPrefix = "temporary-expires:";
    private static readonly TimeSpan DefaultTemporaryRetention = TimeSpan.FromHours(24);
    private static readonly HashSet<string> DefaultFolderImportExcludedDirectoryNames = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git", ".vs", ".idea", "bin", "obj", "node_modules", "packages"
    };

    private static readonly HashSet<string> TextExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".md", ".txt", ".json", ".xml", ".csv", ".cs", ".cshtml", ".razor", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
        ".css", ".scss", ".sql", ".log", ".yaml", ".yml", ".ini", ".config", ".props", ".targets", ".csproj", ".sln", ".ps1", ".sh", ".bat"
    };

    private readonly DynomaxDbContext _db;
    private readonly IAgentArtifactStore _artifactStore;
    private readonly IAuditWriter _audit;

    public ProjectContextService(DynomaxDbContext db, IAgentArtifactStore artifactStore, IAuditWriter audit)
    {
        _db = db;
        _artifactStore = artifactStore;
        _audit = audit;
    }

    public ProjectContextCapabilities GetCapabilities(ProjectContextRequestAccess access)
    {
        RequireProject(access, access.ProjectId);
        return new ProjectContextCapabilities(
            true,
            [ProjectContextSourceTypes.UploadedFiles],
            ["Metadata", "Text", "BinaryResource", "ArchiveEntry"],
            [ProjectContextArchiveTypes.Zip],
            true,
            true,
            ProjectContextLimits.MaxRetainedVersionsPerResource,
            "SHA-256",
            ProjectContextLimits.MaxUploadBytes,
            ProjectContextLimits.MaxAgentBinaryTransferBytes,
            ProjectContextLimits.MaxAgentBinarySegmentBytes,
            ProjectContextLimits.MaxInlineTextCharacters,
            ProjectContextLimits.MaxArchiveEntries,
            ProjectContextLimits.MaxArchiveUncompressedBytes,
            ProjectContextLimits.MaxSingleArchiveEntryBytes,
            ProjectContextLimits.MaxCompressionRatio,
            ProjectContextLimits.MaxArchivePathLength,
            true,
            true,
            true,
            true,
            access.CanRead,
            access.CanUpload,
            access.CanManage,
            access.CanDelete);
    }

    public async Task<ProjectContextSourceSummary> EnsureUploadedFilesSourceAsync(ProjectContextRequestAccess access, CancellationToken cancellationToken)
    {
        Require(access.CanRead || access.CanUpload || access.CanManage, "Project Context access is required.");
        RequireProject(access, access.ProjectId);
        ProjectContextSource? existing = await _db.ProjectContextSources
            .SingleOrDefaultAsync(x => x.ProjectId == access.ProjectId && x.SourceType == ProjectContextSourceTypes.UploadedFiles, cancellationToken);
        if (existing is null)
        {
            bool projectExists = await _db.Projects.AsNoTracking().AnyAsync(x => x.Id == access.ProjectId, cancellationToken);
            if (!projectExists) throw new KeyNotFoundException("Project was not found.");
            existing = new ProjectContextSource(access.ProjectId, ProjectContextSourceTypes.UploadedFiles, "Uploaded Files",
                "Files uploaded to this Project for durable human and agent context.", true, access.ActorUserId, DateTime.UtcNow);
            await _db.ProjectContextSources.AddAsync(existing, cancellationToken);
            try { await _db.SaveChangesAsync(cancellationToken); }
            catch (DbUpdateException)
            {
                _db.Entry(existing).State = EntityState.Detached;
                existing = await _db.ProjectContextSources.SingleAsync(
                    x => x.ProjectId == access.ProjectId && x.SourceType == ProjectContextSourceTypes.UploadedFiles, cancellationToken);
            }
        }
        return await SourceSummaryAsync(existing, access.EnforceAgentReadable, cancellationToken);
    }

    public async Task<IReadOnlyList<ProjectContextSourceSummary>> ListSourcesAsync(ProjectContextRequestAccess access, bool includeInactive, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        RequireProject(access, access.ProjectId);
        await RetireExpiredTemporaryResourcesAsync(access, cancellationToken);
        IQueryable<ProjectContextSource> query = _db.ProjectContextSources.AsNoTracking().Where(x => x.ProjectId == access.ProjectId);
        if (!includeInactive) query = query.Where(x => x.IsActive);
        ProjectContextSource[] rows = await query.OrderBy(x => x.DisplayName).ToArrayAsync(cancellationToken);
        var result = new List<ProjectContextSourceSummary>(rows.Length);
        foreach (ProjectContextSource row in rows)
        {
            if (access.EnforceAgentReadable && !row.IsAgentReadable) continue;
            result.Add(await SourceSummaryAsync(row, access.EnforceAgentReadable, cancellationToken));
        }
        return result;
    }

    public async Task<ProjectContextResourcePage> ListResourcesAsync(ProjectContextRequestAccess access, ProjectContextResourceQuery query, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        RequireProject(access, query.ProjectId);
        await RetireExpiredTemporaryResourcesAsync(access, cancellationToken);
        int skip = Math.Max(0, query.Skip);
        int take = Math.Clamp(query.Take <= 0 ? 50 : query.Take, 1, ProjectContextLimits.MaxResourceListTake);

        IQueryable<ProjectContextResource> resources = _db.ProjectContextResources.AsNoTracking()
            .Where(resource => _db.ProjectContextSources.Any(source => source.Id == resource.SourceId && source.ProjectId == query.ProjectId));
        if (access.EnforceAgentReadable)
            resources = resources.Where(resource => resource.CurrentVersionId != null && _db.ProjectContextResourceVersions.Any(version => version.Id == resource.CurrentVersionId && version.AgentReadable));
        if (query.SourceId is Guid sourceId && sourceId != Guid.Empty) resources = resources.Where(x => x.SourceId == sourceId);
        if (!string.IsNullOrWhiteSpace(query.SourceType))
        {
            string sourceType = query.SourceType.Trim();
            resources = resources.Where(resource => _db.ProjectContextSources.Any(source => source.Id == resource.SourceId && source.SourceType == sourceType));
        }
        if (!query.IncludeInactive) resources = resources.Where(x => x.IsActive);
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            string search = query.Search.Trim();
            resources = resources.Where(x => x.DisplayName.Contains(search) || x.LogicalKey.Contains(search));
        }
        if (!string.IsNullOrWhiteSpace(query.Category))
        {
            string category = query.Category.Trim();
            resources = resources.Where(x => x.Category == category);
        }
        if (!string.IsNullOrWhiteSpace(query.LogicalPathPrefix))
        {
            string prefix = query.LogicalPathPrefix.Trim();
            resources = resources.Where(resource => _db.ProjectContextResourceVersions.Any(version =>
                version.ResourceId == resource.Id && version.Id == resource.CurrentVersionId && version.LogicalPath.StartsWith(prefix)));
        }
        if (query.CurrentOnly) resources = resources.Where(x => x.CurrentVersionId != null);
        int total = await resources.CountAsync(cancellationToken);
        ProjectContextResource[] page = await resources.OrderBy(x => x.DisplayName).ThenBy(x => x.Id).Skip(skip).Take(take).ToArrayAsync(cancellationToken);
        IReadOnlyList<ProjectContextResourceSummary> mapped = await MapResourceSummariesAsync(access, page, cancellationToken);
        return new ProjectContextResourcePage(skip, take, total, mapped);
    }

    public async Task<ProjectContextResourceDetails?> GetResourceDetailsAsync(ProjectContextRequestAccess access, Guid resourceId, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        ProjectContextResource? resource = await FindResourceForProjectAsync(access, resourceId, tracking: false, cancellationToken);
        if (resource is null) return null;
        ProjectContextResourceSummary summary = (await MapResourceSummariesAsync(access, [resource], cancellationToken)).Single();
        ProjectContextResourceVersion[] versions = await _db.ProjectContextResourceVersions.AsNoTracking()
            .Where(x => x.ResourceId == resource.Id).OrderByDescending(x => x.VersionNumber).ToArrayAsync(cancellationToken);
        return new ProjectContextResourceDetails(summary, versions
            .Where(x => !access.EnforceAgentReadable || x.AgentReadable)
            .Select(x => MapVersion(x, resource.CurrentVersionId == x.Id)).ToArray());
    }

    public async Task<UploadProjectContextFileResult> UploadAsync(ProjectContextRequestAccess access, UploadProjectContextFileCommand command, CancellationToken cancellationToken)
    {
        Require(access.CanUpload, "ProjectContext.Upload is required.");
        RequireProject(access, command.ProjectId);
        if (command.Content is null || command.Content.LongLength == 0) throw new ArgumentException("File content is required.");
        if (!command.IsTrustedFolderSnapshot && command.Content.LongLength > ProjectContextLimits.MaxUploadBytes) throw new ArgumentOutOfRangeException(nameof(command.Content), $"Project Context files may not exceed {ProjectContextLimits.MaxUploadBytes} bytes each.");
        string fileName = SafeFileName(command.FileName);
        string contentType = NormalizeContentType(command.ContentType, fileName);
        string requestedLogicalPath = string.IsNullOrWhiteSpace(command.LogicalName) ? fileName : command.LogicalName.Trim();
        string logicalPath = NormalizeLogicalPath(requestedLogicalPath);
        string logicalKey = NormalizeLogicalKey(logicalPath);
        string displayName = DisplayNameFromLogicalPath(logicalPath);
        string sha256 = Sha256(command.Content);
        IReadOnlyList<PendingArchiveEntry> archiveEntries = [];
        string? archiveType = null;
        if (IsZip(fileName, contentType))
        {
            contentType = "application/zip";
            if (command.AgentReadable)
            {
                archiveEntries = InspectZip(command.Content, command.IsTrustedFolderSnapshot);
                archiveType = ProjectContextArchiveTypes.Zip;
            }
        }
        DateTime now = command.UploadedAtUtc.Kind == DateTimeKind.Utc ? command.UploadedAtUtc : command.UploadedAtUtc.ToUniversalTime();
        string[] requestedTags = command.Tags.Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x.Trim()).Distinct(StringComparer.OrdinalIgnoreCase).Take(50).ToArray();
        bool isTemporary = IsTemporaryTags(requestedTags);
        string[] normalizedTags = isTemporary ? EnsureTemporaryExpiryTag(requestedTags, now) : requestedTags;
        string tagsJson = JsonSerializer.Serialize(normalizedTags);
        bool isAuthoritative = command.IsAuthoritative && !isTemporary;
        bool agentReadable = command.AgentReadable;
        string? category = string.IsNullOrWhiteSpace(command.Category) ? null : command.Category.Trim();
        string? description = string.IsNullOrWhiteSpace(command.Description) ? null : command.Description.Trim();

        IExecutionStrategy strategy = _db.Database.CreateExecutionStrategy();
        (UploadProjectContextFileResult Result, bool CreatedVersion) outcome = await strategy.ExecuteAsync(async () =>
        {
            await using IDbContextTransaction transaction = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
            ProjectContextSourceSummary sourceSummary = await EnsureUploadedFilesSourceAsync(access, cancellationToken);
            ProjectContextResource? resource;
            if (command.TargetResourceId is Guid targetResourceId && targetResourceId != Guid.Empty)
            {
                resource = await _db.ProjectContextResources.SingleOrDefaultAsync(x => x.Id == targetResourceId && x.SourceId == sourceSummary.SourceId, cancellationToken)
                    ?? throw new KeyNotFoundException("Project Context resource was not found.");
                if (!resource.IsActive) throw new InvalidOperationException("Retired Project Context files cannot receive a new version. Restore the file first.");
                if (command.ExpectedCurrentVersionId is not Guid expectedCurrentVersionId || expectedCurrentVersionId == Guid.Empty)
                    throw new ArgumentException("Expected Current version ID is required when replacing an existing Project Context file.", nameof(command));
                if (resource.CurrentVersionId != expectedCurrentVersionId)
                    throw new InvalidOperationException("This file has changed since you opened the replacement dialog. Refresh Project Context and try again.");
                ProjectContextResourceVersion currentTargetVersion = await _db.ProjectContextResourceVersions
                    .SingleAsync(version => version.Id == expectedCurrentVersionId && version.ResourceId == resource.Id, cancellationToken);
                if (command.ClientLastModifiedUtc is DateTime clientModified)
                {
                    DateTime clientModifiedUtc = clientModified.Kind == DateTimeKind.Utc ? clientModified : clientModified.ToUniversalTime();
                    if (clientModifiedUtc < currentTargetVersion.CreatedAtUtc && !command.AllowOlderFile)
                        throw new InvalidOperationException("The selected file appears older than the Current Project Context version. Confirm 'Use older file anyway' to continue.");
                }
                logicalPath = currentTargetVersion.LogicalPath;
                logicalKey = resource.LogicalKey;
                displayName = resource.DisplayName;
                category = resource.Category;
                description = resource.Description;
                tagsJson = resource.TagsJson;
                isAuthoritative = resource.IsAuthoritative;
                agentReadable = currentTargetVersion.AgentReadable;
                archiveEntries = [];
                archiveType = null;
                if (IsZip(fileName, contentType))
                {
                    contentType = "application/zip";
                    if (agentReadable)
                    {
                        archiveEntries = InspectZip(command.Content, command.IsTrustedFolderSnapshot);
                        archiveType = ProjectContextArchiveTypes.Zip;
                    }
                }
            }
            else
            {
                resource = await _db.ProjectContextResources.SingleOrDefaultAsync(x => x.SourceId == sourceSummary.SourceId && x.LogicalKey == logicalKey, cancellationToken);
            }
            if (resource is null)
            {
                resource = new ProjectContextResource(sourceSummary.SourceId, logicalKey, displayName, category, description, tagsJson,
                    isAuthoritative, command.ActorUserId, now);
                await _db.ProjectContextResources.AddAsync(resource, cancellationToken);
                // Break the Resource -> CurrentVersion / Version -> Resource FK cycle while keeping the whole upload atomic in this retriable transaction.
                await _db.SaveChangesAsync(cancellationToken);
            }
            else
            {
                bool restored = !resource.IsActive;
                if (restored) resource.Restore(command.ActorUserId, now);
                bool metadataChanged = !string.Equals(resource.DisplayName, displayName, StringComparison.Ordinal) ||
                    !string.Equals(resource.Category, category, StringComparison.Ordinal) ||
                    !string.Equals(resource.Description, description, StringComparison.Ordinal) ||
                    !string.Equals(resource.TagsJson, tagsJson, StringComparison.Ordinal) ||
                    resource.IsAuthoritative != isAuthoritative;
                if (metadataChanged) resource.UpdateMetadata(displayName, category, description, tagsJson, isAuthoritative, command.ActorUserId, now);
            }

            ProjectContextResourceVersion? equivalent = await _db.ProjectContextResourceVersions
                .Where(x => x.ResourceId == resource.Id && x.Sha256 == sha256 && x.AgentReadable == agentReadable)
                .OrderByDescending(x => x.VersionNumber)
                .FirstOrDefaultAsync(cancellationToken);
            if (equivalent is not null)
            {
                if (command.MarkCurrent || resource.CurrentVersionId is null) resource.SetCurrent(equivalent.Id, command.ActorUserId, now);
                await _db.SaveChangesAsync(cancellationToken);
                await transaction.CommitAsync(cancellationToken);
                return (new UploadProjectContextFileResult(sourceSummary.SourceId, resource.Id, equivalent.Id, equivalent.VersionNumber,
                    resource.CurrentVersionId == equivalent.Id, equivalent.Sha256, equivalent.SizeBytes, equivalent.ArchiveType, equivalent.ArchiveEntryCount), false);
            }

            ProjectContextResourceVersion? previous = await _db.ProjectContextResourceVersions
                .Where(x => x.ResourceId == resource.Id).OrderByDescending(x => x.VersionNumber).FirstOrDefaultAsync(cancellationToken);
            int versionNumber = (previous?.VersionNumber ?? 0) + 1;
            AgentArtifact? artifact = await _db.AgentArtifacts.SingleOrDefaultAsync(x =>
                x.ProjectId == access.ProjectId && x.Kind == AgentArtifactKinds.ProjectContextFile && x.Sha256 == sha256 && x.SessionId == null && x.RunRequestId == null,
                cancellationToken);
            if (artifact is null)
            {
                artifact = new AgentArtifact(access.ProjectId, null, null, AgentArtifactKinds.ProjectContextFile, fileName, contentType, command.Content.LongLength,
                    sha256, agentReadable, JsonSerializer.Serialize(new { projectId = access.ProjectId, kind = "ProjectContextFile" }), "[]", now, null);
                await _db.AgentArtifacts.AddAsync(artifact, cancellationToken);
                await _artifactStore.WriteDerivedAsync(artifact.Id, command.Content, sha256, now, cancellationToken, allowProjectContextContent: true);
            }
            else
            {
                StoredAgentArtifactContent? existingContent = await _artifactStore.ReadDerivedAsync(artifact.Id, cancellationToken);
                if (existingContent is null || existingContent.Bytes.LongLength != command.Content.LongLength ||
                    !string.Equals(existingContent.Sha256, sha256, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidOperationException("An existing Project Context artifact descriptor failed immutable storage verification.");
            }

            var version = new ProjectContextResourceVersion(resource.Id, versionNumber, fileName, logicalPath, contentType, command.Content.LongLength,
                sha256, artifact.Id, agentReadable, "ProjectContext", archiveType, archiveEntries.Count == 0 ? null : archiveEntries.Count,
                command.ActorUserId, now, previous?.Id);
            await _db.ProjectContextResourceVersions.AddAsync(version, cancellationToken);
            foreach (PendingArchiveEntry entry in archiveEntries)
            {
                await _db.ProjectContextArchiveEntries.AddAsync(new ProjectContextArchiveEntry(version.Id, entry.CanonicalPath, entry.OriginalPath,
                    entry.IsDirectory, entry.UncompressedBytes, entry.CompressedBytes, entry.ContentType, entry.IsText, entry.Sha256), cancellationToken);
            }
            if (command.MarkCurrent || resource.CurrentVersionId is null) resource.SetCurrent(version.Id, command.ActorUserId, now);
            await _db.SaveChangesAsync(cancellationToken);
            await PruneVersionHistoryAsync(resource, cancellationToken);
            await transaction.CommitAsync(cancellationToken);

            return (new UploadProjectContextFileResult(sourceSummary.SourceId, resource.Id, version.Id, versionNumber, resource.CurrentVersionId == version.Id,
                sha256, command.Content.LongLength, archiveType, archiveEntries.Count == 0 ? null : archiveEntries.Count), true);
        });

        await AuditAsync(access, outcome.CreatedVersion ? "ProjectContext.Upload" : "ProjectContext.UploadNoOp", "ProjectContextResourceVersion", outcome.Result.ResourceVersionId, true,
            new { resourceId = outcome.Result.ResourceId, versionNumber = outcome.Result.VersionNumber, logicalPath, fileName, sizeBytes = outcome.Result.SizeBytes, sha256 = outcome.Result.Sha256, createdVersion = outcome.CreatedVersion, targetResourceId = command.TargetResourceId, expectedCurrentVersionId = command.ExpectedCurrentVersionId, clientLastModifiedUtc = command.ClientLastModifiedUtc, allowOlderFile = command.AllowOlderFile, archiveType = outcome.Result.ArchiveType, archiveEntryCount = outcome.Result.ArchiveEntryCount }, cancellationToken);
        return outcome.Result;
    }

    public async Task<ImportProjectContextFolderResult> ImportLocalFolderAsync(ProjectContextRequestAccess access, ImportProjectContextFolderCommand command, CancellationToken cancellationToken)
    {
        Require(access.CanUpload && access.CanManage, "ProjectContext.Upload and ProjectContext.Manage are required for local folder import.");
        RequireProject(access, command.ProjectId);
        if (string.IsNullOrWhiteSpace(command.FolderPath)) throw new ArgumentException("A local folder path is required.", nameof(command));

        string root = Path.GetFullPath(command.FolderPath.Trim()).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (!Directory.Exists(root)) throw new DirectoryNotFoundException("The selected local folder does not exist on the Dynomax host.");
        FileAttributes rootAttributes = File.GetAttributes(root);
        if ((rootAttributes & FileAttributes.ReparsePoint) != 0) throw new InvalidOperationException("Local folder imports may not start from a symbolic link or reparse point.");

        var files = new List<(string FullPath, string RelativePath, long Length)>();
        var pending = new Stack<string>();
        pending.Push(root);
        long sourceBytes = 0;
        while (pending.Count > 0)
        {
            cancellationToken.ThrowIfCancellationRequested();
            string directory = pending.Pop();
            foreach (string childDirectory in Directory.EnumerateDirectories(directory))
            {
                cancellationToken.ThrowIfCancellationRequested();
                FileAttributes attributes;
                try { attributes = File.GetAttributes(childDirectory); }
                catch (UnauthorizedAccessException) { continue; }
                if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
                string directoryName = Path.GetFileName(childDirectory);
                if (command.ExcludeGeneratedDirectories && DefaultFolderImportExcludedDirectoryNames.Contains(directoryName)) continue;
                pending.Push(childDirectory);
            }

            foreach (string file in Directory.EnumerateFiles(directory))
            {
                cancellationToken.ThrowIfCancellationRequested();
                FileAttributes attributes;
                try { attributes = File.GetAttributes(file); }
                catch (UnauthorizedAccessException) { continue; }
                if ((attributes & FileAttributes.ReparsePoint) != 0) continue;
                var info = new FileInfo(file);
                if (info.Length > ProjectContextLimits.MaxUploadBytes)
                    throw new InvalidOperationException($"Folder file '{Path.GetFileName(file)}' exceeds the {ProjectContextLimits.MaxUploadBytes / (1024 * 1024)} MiB per-file Project Context limit.");
                sourceBytes = checked(sourceBytes + info.Length);
                string relative = CanonicalArchivePath(Path.GetRelativePath(root, file), allowDirectory: false);
                files.Add((file, relative, info.Length));
                if (files.Count > ProjectContextLimits.MaxArchiveEntries)
                    throw new InvalidOperationException($"Folder contains more than {ProjectContextLimits.MaxArchiveEntries} importable files.");
            }
        }

        if (files.Count == 0) throw new InvalidOperationException("The selected local folder contains no importable files.");
        files.Sort((left, right) => StringComparer.OrdinalIgnoreCase.Compare(left.RelativePath, right.RelativePath));

        string folderName = Path.GetFileName(root);
        if (string.IsNullOrWhiteSpace(folderName)) folderName = "folder";
        string collectionPath = NormalizeLogicalPath(string.IsNullOrWhiteSpace(command.LogicalName) ? folderName : command.LogicalName.Trim());
        string collectionKey = NormalizeLogicalKey(collectionPath);
        string collectionPrefix = collectionKey + "/";
        string[] tags = new[] { "folder-import", $"collection:{collectionKey}" }.Concat(command.Tags)
            .Where(value => !string.IsNullOrWhiteSpace(value)).Distinct(StringComparer.OrdinalIgnoreCase).Take(50).ToArray();
        var seenKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        UploadProjectContextFileResult? firstUpload = null;

        foreach ((string fullPath, string relativePath, long length) in files)
        {
            cancellationToken.ThrowIfCancellationRequested();
            string logicalPath = NormalizeLogicalPath(collectionPath + "/" + relativePath);
            string logicalKey = NormalizeLogicalKey(logicalPath);
            seenKeys.Add(logicalKey);

            byte[] content;
            await using (var source = new FileStream(fullPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete, 81920, FileOptions.Asynchronous | FileOptions.SequentialScan))
            {
                if (source.Length != length && source.Length > ProjectContextLimits.MaxUploadBytes)
                    throw new InvalidOperationException($"Folder file '{relativePath}' changed during import and now exceeds the {ProjectContextLimits.MaxUploadBytes / (1024 * 1024)} MiB per-file Project Context limit.");
                using var target = new MemoryStream(checked((int)source.Length));
                await source.CopyToAsync(target, cancellationToken);
                content = target.ToArray();
            }

            UploadProjectContextFileResult upload = await UploadAsync(access, new UploadProjectContextFileCommand(
                command.ProjectId, Path.GetFileName(relativePath), GuessContentType(relativePath), content, logicalPath, command.Category, command.Description, tags,
                command.MarkCurrent, command.AgentReadable, command.IsAuthoritative, command.ActorUserId, command.ImportedAtUtc), cancellationToken);
            firstUpload ??= upload;
        }

        ProjectContextSourceSummary sourceSummary = await EnsureUploadedFilesSourceAsync(access, cancellationToken);
        ProjectContextResource[] existingCollectionResources = await _db.ProjectContextResources
            .Where(x => x.SourceId == sourceSummary.SourceId && x.IsActive && (x.LogicalKey == collectionKey || x.LogicalKey.StartsWith(collectionPrefix)))
            .ToArrayAsync(cancellationToken);
        DateTime now = command.ImportedAtUtc.Kind == DateTimeKind.Utc ? command.ImportedAtUtc : command.ImportedAtUtc.ToUniversalTime();
        foreach (ProjectContextResource resource in existingCollectionResources)
        {
            if (seenKeys.Contains(resource.LogicalKey)) continue;
            bool legacySnapshotRoot = string.Equals(resource.LogicalKey, collectionKey, StringComparison.OrdinalIgnoreCase) &&
                ParseTags(resource.TagsJson).Any(tag => string.Equals(tag, "folder-snapshot", StringComparison.OrdinalIgnoreCase));
            if (legacySnapshotRoot || resource.LogicalKey.StartsWith(collectionPrefix, StringComparison.OrdinalIgnoreCase))
                resource.Retire(command.ActorUserId, now);
        }
        await _db.SaveChangesAsync(cancellationToken);

        UploadProjectContextFileResult representative = firstUpload ?? throw new InvalidOperationException("Folder reconciliation produced no Project Context files.");
        await AuditAsync(access, "ProjectContext.ImportLocalFolder", "ProjectContextResourceVersion", representative.ResourceVersionId, true,
            new { collectionPath, fileCount = files.Count, sourceBytes, excludeGeneratedDirectories = command.ExcludeGeneratedDirectories, reconciliation = "per-file" }, cancellationToken);
        return new ImportProjectContextFolderResult(representative, collectionPath, files.Count, sourceBytes);
    }

    public async Task<ProjectContextVersionSummary> ResolveAsync(ProjectContextRequestAccess access, ResolveProjectContextResourceRequest request, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        RequireProject(access, request.ProjectId);
        ProjectContextResource? resource = null;
        if (request.ResourceId is Guid resourceId && resourceId != Guid.Empty)
            resource = await FindResourceForProjectAsync(access, resourceId, tracking: false, cancellationToken);
        else if (!string.IsNullOrWhiteSpace(request.LogicalKey))
        {
            string logicalKey = NormalizeLogicalKey(request.LogicalKey);
            resource = await _db.ProjectContextResources.AsNoTracking().SingleOrDefaultAsync(r => r.LogicalKey == logicalKey &&
                _db.ProjectContextSources.Any(s => s.Id == r.SourceId && s.ProjectId == request.ProjectId), cancellationToken);
        }
        if (resource is null) throw new KeyNotFoundException("Project Context resource was not found.");

        string selector = string.IsNullOrWhiteSpace(request.Selector) ? ProjectContextVersionSelectors.Current : request.Selector.Trim();
        IQueryable<ProjectContextResourceVersion> versions = _db.ProjectContextResourceVersions.AsNoTracking().Where(x => x.ResourceId == resource.Id);
        ProjectContextResourceVersion? version = selector switch
        {
            ProjectContextVersionSelectors.Current => resource.CurrentVersionId is Guid currentId ? await versions.SingleOrDefaultAsync(x => x.Id == currentId, cancellationToken) : null,
            ProjectContextVersionSelectors.LatestVersion => await versions.OrderByDescending(x => x.VersionNumber).FirstOrDefaultAsync(cancellationToken),
            ProjectContextVersionSelectors.ExactVersion when request.VersionNumber is int number => await versions.SingleOrDefaultAsync(x => x.VersionNumber == number, cancellationToken),
            ProjectContextVersionSelectors.ExactResourceVersionId when request.ResourceVersionId is Guid exactId => await versions.SingleOrDefaultAsync(x => x.Id == exactId, cancellationToken),
            ProjectContextVersionSelectors.ExactSha256 when !string.IsNullOrWhiteSpace(request.Sha256) => await versions.OrderByDescending(x => x.VersionNumber).FirstOrDefaultAsync(x => x.Sha256 == request.Sha256.Trim().ToLowerInvariant(), cancellationToken),
            _ => throw new ArgumentException("Unsupported or incomplete Project Context version selector.", nameof(request))
        };
        if (version is null) throw new KeyNotFoundException("Requested Project Context resource version was not found.");
        RequireAgentReadable(access, version);
        return MapVersion(version, resource.CurrentVersionId == version.Id);
    }

    public async Task<ProjectContextVersionSummary> GetVersionMetadataAsync(ProjectContextRequestAccess access, Guid resourceVersionId, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        (ProjectContextResource resource, ProjectContextResourceVersion version) = await GetVersionForProjectAsync(access, resourceVersionId, cancellationToken);
        RequireAgentReadable(access, version);
        return MapVersion(version, resource.CurrentVersionId == version.Id);
    }

    public async Task<ProjectContextTextResult> GetTextAsync(ProjectContextRequestAccess access, Guid resourceVersionId, int? offset, int? maxCharacters, int? lineStart, int? lineCount, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        (ProjectContextResource _, ProjectContextResourceVersion version) = await GetVersionForProjectAsync(access, resourceVersionId, cancellationToken);
        RequireAgentReadable(access, version);
        if (!IsTextFile(version.OriginalFileName, version.ContentType)) throw new InvalidOperationException("The selected resource is not classified as safely textual. Use the binary file action.");
        byte[] bytes = await ReadArtifactVerifiedAsync(version, cancellationToken);
        string text;
        try { text = StrictUtf8.GetString(bytes).TrimStart('\uFEFF'); }
        catch (DecoderFallbackException) { throw new InvalidOperationException("The selected resource is not valid UTF-8 text."); }
        int max = Math.Clamp(maxCharacters ?? 100_000, 1, ProjectContextLimits.MaxInlineTextCharacters);
        int returnedOffset;
        string content;
        bool hasMore;
        if (lineStart is int requestedLine)
        {
            int startLine = Math.Max(1, requestedLine);
            int count = Math.Clamp(lineCount ?? 200, 1, 5000);
            string[] lines = text.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n').Split('\n');
            int index = Math.Min(startLine - 1, lines.Length);
            content = string.Join('\n', lines.Skip(index).Take(count));
            if (content.Length > max) content = content[..max];
            returnedOffset = index;
            hasMore = index + count < lines.Length || content.Length == max;
        }
        else
        {
            int start = Math.Clamp(offset ?? 0, 0, text.Length);
            int length = Math.Min(max, text.Length - start);
            content = text.Substring(start, length);
            returnedOffset = start;
            hasMore = start + length < text.Length;
        }
        await AuditAsync(access, "ProjectContext.ReadText", "ProjectContextResourceVersion", version.Id, true,
            new { returnedOffset, returnedCharacters = content.Length, hasMore }, cancellationToken);
        return new ProjectContextTextResult(version.Id, version.OriginalFileName, version.ContentType, version.Sha256, version.SizeBytes, "utf-8",
            returnedOffset, content.Length, hasMore, content);
    }

    public async Task<ProjectContextBinaryResult> GetFileAsync(ProjectContextRequestAccess access, Guid resourceVersionId, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        (ProjectContextResource resource, ProjectContextResourceVersion version) = await GetVersionForProjectAsync(access, resourceVersionId, cancellationToken);
        RequireAgentReadable(access, version);
        byte[] bytes = await ReadArtifactVerifiedAsync(version, cancellationToken);
        await AuditAsync(access, "ProjectContext.ReadFile", "ProjectContextResourceVersion", version.Id, true,
            new { sizeBytes = version.SizeBytes, sha256 = version.Sha256 }, cancellationToken);
        return new ProjectContextBinaryResult(resource.Id, version.Id, version.OriginalFileName, version.ContentType, bytes, version.Sha256, version.SizeBytes, version.Classification);
    }

    public async Task<ProjectContextBinarySegmentResult> GetFileSegmentAsync(ProjectContextRequestAccess access, Guid resourceVersionId, long offset, int? maxBytes, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        (ProjectContextResource resource, ProjectContextResourceVersion version) = await GetVersionForProjectAsync(access, resourceVersionId, cancellationToken);
        RequireAgentReadable(access, version);
        if (offset < 0 || offset >= version.SizeBytes) throw new ArgumentOutOfRangeException(nameof(offset), "Segment offset must address a byte inside the immutable resource.");
        int requested = Math.Clamp(maxBytes ?? ProjectContextLimits.MaxAgentBinarySegmentBytes, 1, ProjectContextLimits.MaxAgentBinarySegmentBytes);
        int count = checked((int)Math.Min(requested, version.SizeBytes - offset));
        byte[] bytes = await ReadArtifactVerifiedAsync(version, cancellationToken);
        byte[] segment = new byte[count];
        Buffer.BlockCopy(bytes, checked((int)offset), segment, 0, count);
        string segmentSha256 = Sha256(segment);
        bool hasMore = offset + count < version.SizeBytes;
        await AuditAsync(access, "ProjectContext.ReadFileSegment", "ProjectContextResourceVersion", version.Id, true,
            new { offset, returnedBytes = count, hasMore, resourceSizeBytes = version.SizeBytes, segmentSha256, resourceSha256 = version.Sha256 }, cancellationToken);
        return new ProjectContextBinarySegmentResult(resource.Id, version.Id, version.OriginalFileName, version.ContentType, segment, segmentSha256,
            offset, count, hasMore, version.Sha256, version.SizeBytes, version.Classification);
    }

    public async Task<ProjectContextArchiveEntryPage> ListArchiveEntriesAsync(ProjectContextRequestAccess access, Guid resourceVersionId, string? pathPrefix, string? search, string? extension, int skip, int take, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        (ProjectContextResource _, ProjectContextResourceVersion version) = await GetVersionForProjectAsync(access, resourceVersionId, cancellationToken);
        RequireAgentReadable(access, version);
        if (!string.Equals(version.ArchiveType, ProjectContextArchiveTypes.Zip, StringComparison.Ordinal)) throw new InvalidOperationException("The selected resource version is not an indexed ZIP archive.");
        IQueryable<ProjectContextArchiveEntry> entries = _db.ProjectContextArchiveEntries.AsNoTracking().Where(x => x.ResourceVersionId == version.Id);
        if (!string.IsNullOrWhiteSpace(pathPrefix)) { string prefix = CanonicalArchivePath(pathPrefix, allowDirectory: true); entries = entries.Where(x => x.CanonicalPath.StartsWith(prefix)); }
        if (!string.IsNullOrWhiteSpace(search)) { string term = search.Trim(); entries = entries.Where(x => x.CanonicalPath.Contains(term)); }
        if (!string.IsNullOrWhiteSpace(extension)) { string ext = extension.Trim().StartsWith('.') ? extension.Trim() : "." + extension.Trim(); entries = entries.Where(x => x.CanonicalPath.EndsWith(ext)); }
        int normalizedSkip = Math.Max(0, skip);
        int normalizedTake = Math.Clamp(take <= 0 ? 100 : take, 1, ProjectContextLimits.MaxArchiveListTake);
        int total = await entries.CountAsync(cancellationToken);
        ProjectContextArchiveEntrySummary[] items = await entries.OrderBy(x => x.CanonicalPath).Skip(normalizedSkip).Take(normalizedTake)
            .Select(x => new ProjectContextArchiveEntrySummary(x.ResourceVersionId, x.CanonicalPath, x.UncompressedBytes, x.CompressedBytes, x.ContentType, x.IsDirectory, x.IsText, x.Sha256))
            .ToArrayAsync(cancellationToken);
        return new ProjectContextArchiveEntryPage(normalizedSkip, normalizedTake, total, items);
    }

    public async Task<ProjectContextArchiveEntryResult> GetArchiveEntryAsync(ProjectContextRequestAccess access, Guid resourceVersionId, string canonicalPath, CancellationToken cancellationToken)
    {
        Require(access.CanRead, "ProjectContext.Read is required.");
        (ProjectContextResource _, ProjectContextResourceVersion version) = await GetVersionForProjectAsync(access, resourceVersionId, cancellationToken);
        RequireAgentReadable(access, version);
        if (!string.Equals(version.ArchiveType, ProjectContextArchiveTypes.Zip, StringComparison.Ordinal)) throw new InvalidOperationException("The selected resource version is not an indexed ZIP archive.");
        string normalized = CanonicalArchivePath(canonicalPath, allowDirectory: false);
        ProjectContextArchiveEntry entry = await _db.ProjectContextArchiveEntries.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ResourceVersionId == version.Id && x.CanonicalPath == normalized, cancellationToken)
            ?? throw new KeyNotFoundException("Archive entry was not found.");
        if (entry.IsDirectory) throw new InvalidOperationException("A directory cannot be fetched as content.");
        byte[] archiveBytes = await ReadArtifactVerifiedAsync(version, cancellationToken);
        byte[] content;
        using (var stream = new MemoryStream(archiveBytes, writable: false))
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: false))
        {
            ZipArchiveEntry zipEntry = archive.Entries.SingleOrDefault(x => string.Equals(x.FullName, entry.OriginalPath, StringComparison.Ordinal))
                ?? throw new InvalidOperationException("The indexed ZIP entry is no longer present in the immutable artifact.");
            await using Stream source = zipEntry.Open();
            using var target = new MemoryStream(checked((int)Math.Min(entry.UncompressedBytes, int.MaxValue)));
            await source.CopyToAsync(target, cancellationToken);
            content = target.ToArray();
        }
        string actualSha = Sha256(content);
        if (content.LongLength != entry.UncompressedBytes || entry.Sha256 is null || !string.Equals(actualSha, entry.Sha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("The ZIP entry failed its immutable size/SHA-256 verification.");
        await AuditAsync(access, "ProjectContext.ReadArchiveEntry", "ProjectContextResourceVersion", version.Id, true,
            new { entry = normalized, sizeBytes = content.LongLength, sha256 = actualSha }, cancellationToken);
        return new ProjectContextArchiveEntryResult(version.Id, normalized, entry.ContentType, content, actualSha, content.LongLength, entry.IsText, version.Classification);
    }

    public async Task SetCurrentAsync(ProjectContextRequestAccess access, Guid resourceId, Guid resourceVersionId, CancellationToken cancellationToken)
    {
        Require(access.CanManage, "ProjectContext.Manage is required.");
        ProjectContextResource resource = await FindResourceForProjectAsync(access, resourceId, tracking: true, cancellationToken)
            ?? throw new KeyNotFoundException("Project Context resource was not found.");
        bool belongs = await _db.ProjectContextResourceVersions.AnyAsync(x => x.Id == resourceVersionId && x.ResourceId == resource.Id, cancellationToken);
        if (!belongs) throw new InvalidOperationException("The selected version does not belong to the requested Project Context resource.");
        resource.SetCurrent(resourceVersionId, access.ActorUserId, DateTime.UtcNow);
        await _db.SaveChangesAsync(cancellationToken);
        await AuditAsync(access, "ProjectContext.SetCurrent", "ProjectContextResource", resource.Id, true, new { resourceVersionId }, cancellationToken);
    }

    public async Task RetireAsync(ProjectContextRequestAccess access, Guid resourceId, CancellationToken cancellationToken)
    {
        Require(access.CanManage, "ProjectContext.Manage is required.");
        ProjectContextResource resource = await FindResourceForProjectAsync(access, resourceId, tracking: true, cancellationToken)
            ?? throw new KeyNotFoundException("Project Context resource was not found.");
        resource.Retire(access.ActorUserId, DateTime.UtcNow);
        await _db.SaveChangesAsync(cancellationToken);
        await AuditAsync(access, "ProjectContext.Retire", "ProjectContextResource", resource.Id, true, null, cancellationToken);
    }

    private async Task<ProjectContextSourceSummary> SourceSummaryAsync(ProjectContextSource source, bool agentReadableOnly, CancellationToken cancellationToken)
    {
        IQueryable<ProjectContextResource> resources = _db.ProjectContextResources.AsNoTracking().Where(x => x.SourceId == source.Id && x.IsActive);
        if (agentReadableOnly)
            resources = resources.Where(resource => resource.CurrentVersionId != null && _db.ProjectContextResourceVersions.Any(version => version.Id == resource.CurrentVersionId && version.AgentReadable));
        int resourceCount = await resources.CountAsync(cancellationToken);
        int currentCount = await resources.CountAsync(x => x.CurrentVersionId != null, cancellationToken);
        return new ProjectContextSourceSummary(source.Id, source.ProjectId, source.SourceType, source.DisplayName, source.Description, source.IsActive,
            source.IsAgentReadable, resourceCount, currentCount, source.UpdatedAtUtc);
    }

    private async Task<IReadOnlyList<ProjectContextResourceSummary>> MapResourceSummariesAsync(ProjectContextRequestAccess access, IReadOnlyList<ProjectContextResource> resources, CancellationToken cancellationToken)
    {
        Guid[] versionIds = resources.Where(x => x.CurrentVersionId != null).Select(x => x.CurrentVersionId!.Value).Distinct().ToArray();
        Dictionary<Guid, ProjectContextResourceVersion> versions = await _db.ProjectContextResourceVersions.AsNoTracking()
            .Where(x => versionIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, cancellationToken);
        var output = new List<ProjectContextResourceSummary>(resources.Count);
        foreach (ProjectContextResource resource in resources)
        {
            versions.TryGetValue(resource.CurrentVersionId ?? Guid.Empty, out ProjectContextResourceVersion? current);
            if (access.EnforceAgentReadable && current is not null && !current.AgentReadable) continue;
            output.Add(new ProjectContextResourceSummary(resource.Id, resource.SourceId, resource.LogicalKey, resource.DisplayName, resource.Category,
                resource.Description, ParseTags(resource.TagsJson), resource.IsAuthoritative, resource.IsActive, resource.CurrentVersionId, current?.VersionNumber, current?.OriginalFileName,
                current?.LogicalPath, current?.ContentType, current?.SizeBytes, current?.Sha256, current?.AgentReadable, current?.Classification, current?.ArchiveType, current?.ArchiveEntryCount,
                resource.CreatedAtUtc, resource.UpdatedAtUtc));
        }
        return output;
    }

    private async Task<ProjectContextResource?> FindResourceForProjectAsync(ProjectContextRequestAccess access, Guid resourceId, bool tracking, CancellationToken cancellationToken)
    {
        RequireProject(access, access.ProjectId);
        IQueryable<ProjectContextResource> query = tracking ? _db.ProjectContextResources : _db.ProjectContextResources.AsNoTracking();
        return await query.SingleOrDefaultAsync(resource => resource.Id == resourceId &&
            _db.ProjectContextSources.Any(source => source.Id == resource.SourceId && source.ProjectId == access.ProjectId), cancellationToken);
    }

    private async Task<(ProjectContextResource Resource, ProjectContextResourceVersion Version)> GetVersionForProjectAsync(ProjectContextRequestAccess access, Guid versionId, CancellationToken cancellationToken)
    {
        if (versionId == Guid.Empty) throw new ArgumentException("Resource version ID is required.", nameof(versionId));
        ProjectContextResourceVersion version = await _db.ProjectContextResourceVersions.AsNoTracking().SingleOrDefaultAsync(x => x.Id == versionId, cancellationToken)
            ?? throw new KeyNotFoundException("Project Context resource version was not found.");
        ProjectContextResource resource = await FindResourceForProjectAsync(access, version.ResourceId, tracking: false, cancellationToken)
            ?? throw new UnauthorizedAccessException("The Project Context resource version does not belong to the authorized Project.");
        return (resource, version);
    }

    private async Task<byte[]> ReadArtifactVerifiedAsync(ProjectContextResourceVersion version, CancellationToken cancellationToken)
    {
        StoredAgentArtifactContent stored = await _artifactStore.ReadDerivedAsync(version.AgentArtifactId, cancellationToken)
            ?? throw new InvalidOperationException("The Project Context file bytes are unavailable from the configured artifact store.");
        if (stored.Bytes.LongLength != version.SizeBytes || !string.Equals(stored.Sha256, version.Sha256, StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(Sha256(stored.Bytes), version.Sha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("The Project Context artifact failed immutable SHA-256/length verification.");
        return stored.Bytes;
    }

    private async Task AuditAsync(ProjectContextRequestAccess access, string eventType, string entityType, Guid entityId, bool succeeded, object? details, CancellationToken cancellationToken)
    {
        await _audit.WriteAsync(access.ActorUserId, eventType, entityType, entityId.ToString("D"), succeeded, details,
            Guid.NewGuid().ToString("N"), null, cancellationToken);
    }

    private static ProjectContextVersionSummary MapVersion(ProjectContextResourceVersion version, bool current) =>
        new(version.Id, version.ResourceId, version.VersionNumber, version.OriginalFileName, version.LogicalPath, version.ContentType, version.SizeBytes,
            version.Sha256, current, version.AgentReadable, version.Classification, version.ArchiveType, version.ArchiveEntryCount, version.CreatedAtUtc, version.SupersedesVersionId);

    private static void RequireAgentReadable(ProjectContextRequestAccess access, ProjectContextResourceVersion version)
    {
        if (access.EnforceAgentReadable && !version.AgentReadable) throw new UnauthorizedAccessException("This Project Context resource version is not agent-readable.");
    }

    private static void RequireProject(ProjectContextRequestAccess access, Guid projectId)
    {
        if (projectId == Guid.Empty || access.ProjectId == Guid.Empty || access.ProjectId != projectId)
            throw new UnauthorizedAccessException("Project Context access is limited to the authorized Project.");
    }

    private static void Require(bool condition, string message)
    {
        if (!condition) throw new UnauthorizedAccessException(message);
    }

    private static string SafeFileName(string value)
    {
        string fileName = Path.GetFileName(value?.Trim() ?? string.Empty);
        if (fileName.Length == 0 || fileName.Length > 260 || fileName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0) throw new ArgumentException("A valid file name is required.", nameof(value));
        return fileName;
    }

    private static string NormalizeLogicalKey(string value)
    {
        string normalized = NormalizeLogicalPath(value).ToLowerInvariant();
        if (normalized.Length > 300) throw new ArgumentException("Logical resource path may not exceed 300 characters.", nameof(value));
        return normalized;
    }

    private static string NormalizeLogicalPath(string value)
    {
        string raw = (value ?? string.Empty).Trim().Replace('\\', '/').Normalize(NormalizationForm.FormC);
        if (raw.Length == 0 || raw.Length > 300 || raw.Any(char.IsControl) || raw.StartsWith('/') ||
            (raw.Length >= 2 && char.IsLetter(raw[0]) && raw[1] == ':'))
            throw new ArgumentException("Logical resource path is invalid.", nameof(value));
        string[] parts = raw.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length == 0 || parts.Any(part => part is "." or "..")) throw new ArgumentException("Logical resource path is invalid.", nameof(value));
        return string.Join('/', parts);
    }

    private static string DisplayNameFromLogicalPath(string logicalPath)
    {
        int separator = logicalPath.LastIndexOf('/');
        return separator >= 0 ? logicalPath[(separator + 1)..] : logicalPath;
    }

    private async Task PruneVersionHistoryAsync(ProjectContextResource resource, CancellationToken cancellationToken)
    {
        int retainedVersionLimit = ProjectContextLimits.MaxRetainedVersionsPerResource; // Current plus at most two backups.
        ProjectContextResourceVersion[] versions = await _db.ProjectContextResourceVersions
            .Where(x => x.ResourceId == resource.Id)
            .OrderByDescending(x => x.VersionNumber)
            .ToArrayAsync(cancellationToken);
        if (versions.Length <= retainedVersionLimit) return;

        var keepIds = new HashSet<Guid>();
        if (resource.CurrentVersionId is Guid currentId) keepIds.Add(currentId);
        foreach (ProjectContextResourceVersion version in versions)
        {
            if (keepIds.Count >= retainedVersionLimit) break;
            keepIds.Add(version.Id);
        }

        ProjectContextResourceVersion[] prune = versions.Where(version => !keepIds.Contains(version.Id)).ToArray();
        if (prune.Length == 0) return;
        var pruneIds = prune.Select(version => version.Id).ToHashSet();
        foreach (ProjectContextResourceVersion version in versions)
        {
            if (version.SupersedesVersionId is Guid supersedes && pruneIds.Contains(supersedes)) version.ClearSupersedesVersion();
        }
        await _db.SaveChangesAsync(cancellationToken);
        Guid[] candidateArtifactIds = prune.Select(version => version.AgentArtifactId).Distinct().ToArray();
        _db.ProjectContextResourceVersions.RemoveRange(prune);
        await _db.SaveChangesAsync(cancellationToken);

        // Project Context file artifacts are content-addressed and may be shared by retained versions.
        // Delete the descriptor (and its cascaded AgentArtifactContent bytes) only when no logical version still references it.
        Guid[] orphanArtifactIds = await _db.AgentArtifacts
            .Where(artifact => candidateArtifactIds.Contains(artifact.Id) &&
                artifact.Kind == AgentArtifactKinds.ProjectContextFile && artifact.SessionId == null && artifact.RunRequestId == null &&
                !_db.ProjectContextResourceVersions.Any(version => version.AgentArtifactId == artifact.Id))
            .Select(artifact => artifact.Id)
            .ToArrayAsync(cancellationToken);
        if (orphanArtifactIds.Length > 0)
        {
            AgentArtifact[] orphanArtifacts = await _db.AgentArtifacts
                .Where(artifact => orphanArtifactIds.Contains(artifact.Id))
                .ToArrayAsync(cancellationToken);
            _db.AgentArtifacts.RemoveRange(orphanArtifacts);
            await _db.SaveChangesAsync(cancellationToken);
        }
    }

    private static string NormalizeContentType(string? contentType, string fileName)
    {
        string normalized = string.IsNullOrWhiteSpace(contentType) ? "application/octet-stream" : contentType.Split(';', 2)[0].Trim().ToLowerInvariant();
        if (normalized.Length > 150) normalized = "application/octet-stream";
        return normalized == "application/octet-stream" ? GuessContentType(fileName) : normalized;
    }

    private static bool IsZip(string fileName, string contentType) => fileName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) || string.Equals(contentType, "application/zip", StringComparison.OrdinalIgnoreCase) || string.Equals(contentType, "application/x-zip-compressed", StringComparison.OrdinalIgnoreCase);

    private static bool IsTextFile(string fileName, string contentType) => contentType.StartsWith("text/", StringComparison.OrdinalIgnoreCase) ||
        contentType is "application/json" or "application/xml" or "application/javascript" or "application/sql" or "application/yaml" || TextExtensions.Contains(Path.GetExtension(fileName));

    private static string GuessContentType(string fileName) => Path.GetExtension(fileName).ToLowerInvariant() switch
    {
        ".zip" => "application/zip", ".json" => "application/json", ".xml" => "application/xml", ".pdf" => "application/pdf",
        ".png" => "image/png", ".jpg" or ".jpeg" => "image/jpeg", ".gif" => "image/gif", ".svg" => "image/svg+xml",
        ".md" or ".txt" or ".log" or ".cs" or ".cshtml" or ".razor" or ".js" or ".ts" or ".css" or ".sql" or ".yaml" or ".yml" or ".csv" => "text/plain",
        _ => "application/octet-stream"
    };

    private static string Sha256(byte[] content) => Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();


    private static bool IsTemporaryTags(IReadOnlyList<string> tags) => tags.Any(tag =>
        string.Equals(tag, "temp", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(tag, "temporary", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(tag, "agent-repair", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(tag, "test-fixture", StringComparison.OrdinalIgnoreCase));

    private static string[] EnsureTemporaryExpiryTag(IReadOnlyList<string> tags, DateTime nowUtc)
    {
        DateTime maximumExpiryUtc = nowUtc.Add(DefaultTemporaryRetention);
        foreach (string tag in tags)
        {
            if (TryReadTemporaryExpiry(tag, out DateTime suppliedExpiryUtc) && suppliedExpiryUtc <= maximumExpiryUtc)
                return tags.Take(50).ToArray();
        }

        long expiresUnixSeconds = new DateTimeOffset(maximumExpiryUtc).ToUnixTimeSeconds();
        return tags
            .Where(tag => !tag.StartsWith(TemporaryExpiryTagPrefix, StringComparison.OrdinalIgnoreCase))
            .Take(49)
            .Append(TemporaryExpiryTagPrefix + expiresUnixSeconds.ToString(System.Globalization.CultureInfo.InvariantCulture))
            .ToArray();
    }

    private static bool TryReadTemporaryExpiry(string tag, out DateTime expiresAtUtc)
    {
        expiresAtUtc = default;
        if (!tag.StartsWith(TemporaryExpiryTagPrefix, StringComparison.OrdinalIgnoreCase)) return false;
        string value = tag[TemporaryExpiryTagPrefix.Length..].Trim();
        if (!long.TryParse(value, System.Globalization.NumberStyles.None, System.Globalization.CultureInfo.InvariantCulture, out long unixSeconds)) return false;
        try
        {
            expiresAtUtc = DateTimeOffset.FromUnixTimeSeconds(unixSeconds).UtcDateTime;
            return true;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }

    private async Task RetireExpiredTemporaryResourcesAsync(ProjectContextRequestAccess access, CancellationToken cancellationToken)
    {
        DateTime nowUtc = DateTime.UtcNow;
        ProjectContextResource[] resources = await _db.ProjectContextResources
            .Where(resource => resource.IsActive &&
                _db.ProjectContextSources.Any(source => source.Id == resource.SourceId && source.ProjectId == access.ProjectId))
            .ToArrayAsync(cancellationToken);

        var retired = new List<Guid>();
        bool changed = false;
        foreach (ProjectContextResource resource in resources)
        {
            IReadOnlyList<string> tags = ParseTags(resource.TagsJson);
            if (!IsTemporaryTags(tags)) continue;

            DateTime? expiresAtUtc = null;
            foreach (string tag in tags)
            {
                if (TryReadTemporaryExpiry(tag, out DateTime parsed))
                {
                    expiresAtUtc = parsed;
                    break;
                }
            }

            if (!expiresAtUtc.HasValue)
            {
                DateTime legacyBaseUtc = resource.UpdatedAtUtc.Kind == DateTimeKind.Utc ? resource.UpdatedAtUtc : resource.UpdatedAtUtc.ToUniversalTime();
                string[] backfilledTags = EnsureTemporaryExpiryTag(tags, legacyBaseUtc);
                resource.UpdateMetadata(resource.DisplayName, resource.Category, resource.Description, JsonSerializer.Serialize(backfilledTags),
                    false, access.ActorUserId, nowUtc);
                changed = true;
                expiresAtUtc = legacyBaseUtc.Add(DefaultTemporaryRetention);
            }

            if (expiresAtUtc.Value <= nowUtc)
            {
                resource.Retire(access.ActorUserId, nowUtc);
                retired.Add(resource.Id);
                changed = true;
            }
        }

        if (!changed) return;
        await _db.SaveChangesAsync(cancellationToken);
        foreach (Guid resourceId in retired)
        {
            await AuditAsync(access, "ProjectContext.TemporaryExpired", "ProjectContextResource", resourceId, true,
                new { retentionHours = DefaultTemporaryRetention.TotalHours }, cancellationToken);
        }
    }

    private static IReadOnlyList<string> ParseTags(string json)
    {
        try { return JsonSerializer.Deserialize<string[]>(json) ?? []; }
        catch (JsonException) { return []; }
    }

    private static IReadOnlyList<PendingArchiveEntry> InspectZip(byte[] content, bool trustedFolderSnapshot = false)
    {
        try
        {
            using var stream = new MemoryStream(content, writable: false);
            using var archive = new ZipArchive(stream, ZipArchiveMode.Read, leaveOpen: false);
            if (archive.Entries.Count > ProjectContextLimits.MaxArchiveEntries) throw new InvalidOperationException($"ZIP contains more than {ProjectContextLimits.MaxArchiveEntries} entries.");
            long total = 0;
            var canonicalPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var result = new List<PendingArchiveEntry>(archive.Entries.Count);
            foreach (ZipArchiveEntry entry in archive.Entries)
            {
                bool directory = entry.FullName.EndsWith('/') || entry.FullName.EndsWith('\\');
                string canonical = CanonicalArchivePath(entry.FullName, directory);
                if (!canonicalPaths.Add(canonical)) throw new InvalidOperationException($"ZIP contains duplicate or ambiguous canonical path '{canonical}'.");
                int unixType = (entry.ExternalAttributes >> 16) & 0xF000;
                if (unixType == 0xA000) throw new InvalidOperationException($"ZIP symbolic-link entry '{canonical}' is not supported.");
                long entryLimit = trustedFolderSnapshot ? ProjectContextLimits.MaxUploadBytes : ProjectContextLimits.MaxSingleArchiveEntryBytes;
                if (entry.Length > entryLimit) throw new InvalidOperationException($"ZIP entry '{canonical}' exceeds the single-entry size limit.");
                total = checked(total + entry.Length);
                if (!trustedFolderSnapshot && total > ProjectContextLimits.MaxArchiveUncompressedBytes) throw new InvalidOperationException("ZIP exceeds the total uncompressed size limit.");
                if (entry.Length > 0)
                {
                    if (entry.CompressedLength <= 0) throw new InvalidOperationException($"ZIP entry '{canonical}' has an unsafe compression ratio.");
                    double ratio = (double)entry.Length / entry.CompressedLength;
                    if (ratio > ProjectContextLimits.MaxCompressionRatio) throw new InvalidOperationException($"ZIP entry '{canonical}' exceeds the compression-ratio limit.");
                }
                string contentType = directory ? "application/x-directory" : GuessContentType(canonical);
                bool isText = !directory && IsTextFile(canonical, contentType);
                string? sha = null;
                if (!directory)
                {
                    using Stream entryStream = entry.Open();
                    using var sha256 = SHA256.Create();
                    sha = Convert.ToHexString(sha256.ComputeHash(entryStream)).ToLowerInvariant();
                }
                result.Add(new PendingArchiveEntry(canonical, entry.FullName, directory, entry.Length, entry.CompressedLength, contentType, isText, sha));
            }
            return result;
        }
        catch (InvalidDataException exception)
        {
            throw new InvalidOperationException("The ZIP archive is malformed or unsupported.", exception);
        }
    }

    private static string CanonicalArchivePath(string value, bool allowDirectory)
    {
        string raw = (value ?? string.Empty).Trim().Replace('\\', '/').Normalize(NormalizationForm.FormC);
        if (raw.Length == 0 || raw.Length > ProjectContextLimits.MaxArchivePathLength || raw.Any(char.IsControl)) throw new InvalidOperationException("Archive path is empty, contains control characters, or exceeds the configured safe length.");
        if (raw.StartsWith('/') || (raw.Length >= 2 && char.IsLetter(raw[0]) && raw[1] == ':')) throw new InvalidOperationException($"Unsafe rooted archive path '{raw}'.");
        string[] parts = raw.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length == 0 || parts.Length > ProjectContextLimits.MaxArchiveDepth || parts.Any(x => x is "." or "..")) throw new InvalidOperationException($"Unsafe archive path '{raw}'.");
        string canonical = string.Join('/', parts);
        if (allowDirectory && (raw.EndsWith('/') || raw.EndsWith('\\'))) canonical += "/";
        return canonical;
    }

    private sealed record PendingArchiveEntry(string CanonicalPath, string OriginalPath, bool IsDirectory, long UncompressedBytes, long CompressedBytes, string ContentType, bool IsText, string? Sha256);
}
