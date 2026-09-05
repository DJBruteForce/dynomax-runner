using System.Text;
using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Domain.ProjectContext;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class RepositoryReadService : IRepositoryReadService
{
    private readonly DynomaxDbContext _db;
    private readonly IRepositoryConnectionService _connections;
    private readonly IRepositoryReadProviderClient _provider;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    public RepositoryReadService(DynomaxDbContext db, IRepositoryConnectionService connections, IRepositoryReadProviderClient provider)
    {
        _db = db;
        _connections = connections;
        _provider = provider;
    }

    public async Task<IReadOnlyList<RepositoryTopologyEntry>> GetTopologyAsync(ProjectContextRequestAccess access, CancellationToken cancellationToken = default)
    {
        RequireRead(access);
        IReadOnlyList<RepositoryConnectionSummary> repositories = await _connections.ListAsync(access, false, cancellationToken);
        return repositories.Select(x => new RepositoryTopologyEntry(x.RepositoryContextId, x.Provider, x.FullName, x.Role, x.Purpose, x.Tags, x.HealthStatus, x.DefaultBranch, x.DefaultBranchHeadSha, x.DefaultTreeSha, x.Policy.AllowRead, x.HealthStatus == RepositoryConnectionHealthStates.Empty && x.DefaultBranchHeadSha is null)).ToArray();
    }

    public async Task<RepositoryTreePage> GetTreeAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string? prefix, int? maxDepth, int skip, int take, CancellationToken cancellationToken = default)
    {
        if (skip < 0 || take < 1 || take > RepositoryReadLimits.MaxTreePageSize || maxDepth is < 0 or > 100)
            throw InvalidPaging("Tree paging/depth is outside the allowed bounds.");
        TargetContext target = await LoadTargetAsync(access, repositoryContextId, cancellationToken);
        TreeState state = await BuildTreeAsync(access, projectEnvironmentId, target, commitSha, maxDepth, cancellationToken);
        string normalizedPrefix = NormalizePath(prefix, true);
        IEnumerable<RepositoryTreeEntry> query = state.Entries;
        if (normalizedPrefix.Length > 0)
            query = query.Where(x => string.Equals(x.Path, normalizedPrefix, StringComparison.Ordinal) || x.Path.StartsWith(normalizedPrefix + "/", StringComparison.Ordinal));
        RepositoryTreeEntry[] filtered = query.OrderBy(x => x.Path, StringComparer.Ordinal).ToArray();
        RepositoryDirectorySummary summary = Summarize(filtered);
        RepositoryTreeEntry[] page = filtered.Skip(skip).Take(take).ToArray();
        return new RepositoryTreePage(target.Repository.Id, target.Repository.FullName, state.CommitSha, state.RootTreeSha, normalizedPrefix, maxDepth, filtered.Length, skip, take, skip + page.Length < filtered.Length, true, summary, page);
    }

    public async Task<RepositorySearchResult> SearchAsync(ProjectContextRequestAccess access, RepositorySearchRequest request, CancellationToken cancellationToken = default)
    {
        RequireRead(access);
        if (request.ProjectEnvironmentId == Guid.Empty) throw InvalidPath("Project environment is required.");
        if (request.Targets is null || request.Targets.Count < 1 || request.Targets.Count > RepositoryReadLimits.MaxSearchRepositories || request.Targets.Select(x => x.RepositoryContextId).Distinct().Count() != request.Targets.Count)
            throw InvalidPaging("Search must target between 1 and 20 unique repository contexts.");
        string needle = request.Query?.Trim() ?? string.Empty;
        if (needle.Length is < 1 or > 200) throw InvalidPaging("Search query must be between 1 and 200 characters.");
        if (request.MaxFilesPerRepository < 1 || request.MaxFilesPerRepository > RepositoryReadLimits.MaxSearchFilesPerRepository || request.MaxMatches < 1 || request.MaxMatches > RepositoryReadLimits.MaxSearchMatches || request.ContextCharacters is < 40 or > 1000)
            throw InvalidPaging("Search bounds are invalid.");
        string prefix = NormalizePath(request.PathPrefix, true);
        var matches = new List<RepositorySearchMatch>();
        int repositoriesScanned = 0, filesScanned = 0, binarySkipped = 0;
        bool truncated = false;
        foreach (RepositoryReadTarget requestedTarget in request.Targets)
        {
            TargetContext target = await LoadTargetAsync(access, requestedTarget.RepositoryContextId, cancellationToken);
            TreeState state = await BuildTreeAsync(access, request.ProjectEnvironmentId, target, requestedTarget.CommitSha, null, cancellationToken);
            repositoriesScanned++;
            if (state.CommitSha is null) continue;
            RepositoryTreeEntry[] files = state.Entries
                .Where(x => x.Kind == RepositoryReadContentKinds.File && !x.IsSymlink && (prefix.Length == 0 || x.Path.StartsWith(prefix + "/", StringComparison.Ordinal) || string.Equals(x.Path, prefix, StringComparison.Ordinal)))
                .OrderBy(x => x.Path, StringComparer.Ordinal)
                .ToArray();
            if (files.Length > request.MaxFilesPerRepository) truncated = true;
            foreach (RepositoryTreeEntry entry in files.Take(request.MaxFilesPerRepository))
            {
                if (matches.Count >= request.MaxMatches) { truncated = true; break; }
                if (entry.Size.HasValue && entry.Size.Value > RepositoryReadLimits.MaxSearchFileBytes) continue;
                RepositoryProviderBlob blob;
                try { blob = await _provider.GetBlobAsync(access.ProjectId, request.ProjectEnvironmentId, target.Repository.CredentialSecretReferenceId, target.Repository.Owner, target.Repository.Name, entry.ObjectSha, RepositoryReadLimits.MaxSearchFileBytes, cancellationToken); }
                catch (RepositoryReadException ex) when (ex.Code == RepositoryReadErrorCodes.TooLarge) { continue; }
                filesScanned++;
                if (!TryDecodeUtf8(blob.Content, out string text)) { binarySkipped++; continue; }
                string[] lines = NormalizeNewlines(text).Split('\n');
                for (int i = 0; i < lines.Length; i++)
                {
                    int index = lines[i].IndexOf(needle, StringComparison.OrdinalIgnoreCase);
                    if (index < 0) continue;
                    matches.Add(new RepositorySearchMatch(target.Repository.Id, target.Repository.FullName, state.CommitSha, entry.Path, entry.ObjectSha, i + 1, MakeSnippet(lines[i], index, request.ContextCharacters)));
                    if (matches.Count >= request.MaxMatches) { truncated = true; break; }
                }
            }
            if (matches.Count >= request.MaxMatches) break;
        }
        return new RepositorySearchResult(needle, repositoriesScanned, filesScanned, binarySkipped, truncated, matches);
    }

    public async Task<RepositoryFileMetadata> GetFileMetadataAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, CancellationToken cancellationToken = default)
    {
        TargetContext target = await LoadTargetAsync(access, repositoryContextId, cancellationToken);
        (TreeState state, RepositoryTreeEntry entry) = await ResolveEntryAsync(access, projectEnvironmentId, target, commitSha, path, cancellationToken);
        if (entry.Kind == RepositoryReadContentKinds.Directory)
            return Metadata(target, state, entry, RepositoryReadContentKinds.Directory, false, false, false, false);
        if (entry.Kind == RepositoryReadContentKinds.Symlink)
            return Metadata(target, state, entry, RepositoryReadContentKinds.Symlink, false, false, false, false);
        if (entry.Kind == RepositoryReadContentKinds.Submodule)
            return Metadata(target, state, entry, RepositoryReadContentKinds.Submodule, false, false, false, false);
        if (entry.Size.HasValue && entry.Size.Value > RepositoryReadLimits.MaxBinaryBlobBytes)
            return Metadata(target, state, entry, RepositoryReadContentKinds.Oversized, false, false, false, false);
        RepositoryProviderBlob blob = await _provider.GetBlobAsync(access.ProjectId, projectEnvironmentId, target.Repository.CredentialSecretReferenceId, target.Repository.Owner, target.Repository.Name, entry.ObjectSha, RepositoryReadLimits.MaxBinaryBlobBytes, cancellationToken);
        bool isText = TryDecodeUtf8(blob.Content, out _);
        return Metadata(target, state, entry, isText ? RepositoryReadContentKinds.Text : RepositoryReadContentKinds.Binary, isText, !isText, isText && blob.Size <= RepositoryReadLimits.MaxTextBlobBytes, !isText);
    }

    public async Task<RepositoryTextPage> ReadTextAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, long? offset, int? maxCharacters, int? lineStart, int? lineCount, CancellationToken cancellationToken = default)
    {
        bool charMode = offset.HasValue || maxCharacters.HasValue;
        bool lineMode = lineStart.HasValue || lineCount.HasValue;
        if (charMode == lineMode) throw InvalidPaging("Choose either character paging or line paging, not both.");
        TargetContext target = await LoadTargetAsync(access, repositoryContextId, cancellationToken);
        (TreeState state, RepositoryTreeEntry entry) = await ResolveReadableFileAsync(access, projectEnvironmentId, target, commitSha, path, cancellationToken);
        if (entry.Size.HasValue && entry.Size.Value > RepositoryReadLimits.MaxTextBlobBytes) throw TooLarge("Text file exceeds the 5 MiB read ceiling. Use metadata and a narrower repository strategy.");
        RepositoryProviderBlob blob = await _provider.GetBlobAsync(access.ProjectId, projectEnvironmentId, target.Repository.CredentialSecretReferenceId, target.Repository.Owner, target.Repository.Name, entry.ObjectSha, RepositoryReadLimits.MaxTextBlobBytes, cancellationToken);
        if (!TryDecodeUtf8(blob.Content, out string decoded)) throw new RepositoryReadException(RepositoryReadErrorCodes.BinaryFile, "Requested repository file is not valid bounded UTF-8 text. Use binary-segment read instead.");
        string text = NormalizeNewlines(decoded);
        int totalLines = text.Split('\n').Length;
        if (charMode)
        {
            long requestedOffset = offset ?? throw InvalidPaging("Character offset is required.");
            int requestedCharacters = maxCharacters ?? throw InvalidPaging("maxCharacters is required.");
            if (requestedOffset < 0 || requestedOffset > text.Length || requestedCharacters < 1 || requestedCharacters > RepositoryReadLimits.MaxTextCharacters) throw InvalidPaging("Character paging is outside the allowed bounds.");
            int start = checked((int)requestedOffset);
            int count = Math.Min(requestedCharacters, text.Length - start);
            return new RepositoryTextPage(target.Repository.Id, target.Repository.FullName, state.CommitSha!, entry.Path, entry.ObjectSha, blob.Size, text.Length, totalLines, start, count, null, null, start + count < text.Length, text.Substring(start, count));
        }
        int requestedLineStart = lineStart ?? throw InvalidPaging("lineStart is required.");
        int requestedLineCount = lineCount ?? throw InvalidPaging("lineCount is required.");
        if (requestedLineStart < 1 || requestedLineCount < 1 || requestedLineCount > 10000) throw InvalidPaging("Line paging is outside the allowed bounds.");
        string[] lines = text.Split('\n');
        if (requestedLineStart > lines.Length) throw InvalidPaging("lineStart is beyond the end of the file.");
        int index = requestedLineStart - 1;
        string selected = string.Join('\n', lines.Skip(index).Take(requestedLineCount));
        if (selected.Length > RepositoryReadLimits.MaxTextCharacters) throw TooLarge("Requested line page exceeds the 200000-character response ceiling; request fewer lines.");
        int returnedLines = Math.Min(requestedLineCount, lines.Length - index);
        return new RepositoryTextPage(target.Repository.Id, target.Repository.FullName, state.CommitSha!, entry.Path, entry.ObjectSha, blob.Size, text.Length, totalLines, null, null, requestedLineStart, returnedLines, index + returnedLines < lines.Length, selected);
    }

    public async Task<RepositoryBinarySegment> ReadBinarySegmentAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, Guid repositoryContextId, string? commitSha, string path, long offset, int maxBytes, CancellationToken cancellationToken = default)
    {
        if (offset < 0 || maxBytes < 1 || maxBytes > RepositoryReadLimits.MaxBinarySegmentBytes) throw InvalidPaging("Binary segment bounds are invalid.");
        TargetContext target = await LoadTargetAsync(access, repositoryContextId, cancellationToken);
        (TreeState state, RepositoryTreeEntry entry) = await ResolveReadableFileAsync(access, projectEnvironmentId, target, commitSha, path, cancellationToken);
        if (entry.Size.HasValue && entry.Size.Value > RepositoryReadLimits.MaxBinaryBlobBytes) throw TooLarge("Binary file exceeds the 10 MiB S013 provider ceiling; large-file cache/stream strategy is delivered in P031-S015.");
        RepositoryProviderBlob blob = await _provider.GetBlobAsync(access.ProjectId, projectEnvironmentId, target.Repository.CredentialSecretReferenceId, target.Repository.Owner, target.Repository.Name, entry.ObjectSha, RepositoryReadLimits.MaxBinaryBlobBytes, cancellationToken);
        if (TryDecodeUtf8(blob.Content, out _)) throw new RepositoryReadException(RepositoryReadErrorCodes.TextFileExpected, "Requested file is UTF-8 text. Use repository text paging instead of binary segment read.");
        if (offset > blob.Content.LongLength) throw InvalidPaging("Binary offset is beyond the end of the file.");
        int start = checked((int)offset);
        int count = Math.Min(maxBytes, blob.Content.Length - start);
        string base64 = Convert.ToBase64String(blob.Content, start, count);
        return new RepositoryBinarySegment(target.Repository.Id, target.Repository.FullName, state.CommitSha!, entry.Path, entry.ObjectSha, blob.Size, offset, count, offset + count < blob.Content.LongLength, base64);
    }

    private async Task<TargetContext> LoadTargetAsync(ProjectContextRequestAccess access, Guid repositoryContextId, CancellationToken cancellationToken)
    {
        RequireRead(access);
        Guid? sourceId = await _db.ProjectContextSources.AsNoTracking().Where(x => x.ProjectId == access.ProjectId && x.SourceType == ProjectContextSourceTypes.GitRepositories).Select(x => (Guid?)x.Id).SingleOrDefaultAsync(cancellationToken);
        if (!sourceId.HasValue) throw NotFound();
        ProjectContextRepository? repository = await _db.ProjectContextRepositories.AsNoTracking().SingleOrDefaultAsync(x => x.Id == repositoryContextId && x.SourceId == sourceId.Value && x.IsActive, cancellationToken);
        if (repository is null) throw NotFound();
        ProjectContextRepositoryPolicy? policy = await _db.ProjectContextRepositoryPolicies.AsNoTracking().SingleOrDefaultAsync(x => x.RepositoryContextId == repositoryContextId, cancellationToken);
        if (policy is null) throw NotFound();
        if (!policy.AllowRead) throw new RepositoryReadException(RepositoryReadErrorCodes.PolicyDenied, "Repository read is denied by the effective repository policy.");
        if (!string.Equals(repository.Provider, "GitHub", StringComparison.OrdinalIgnoreCase)) throw new RepositoryReadException(RepositoryReadErrorCodes.UnsupportedObject, "This repository provider is not supported by the GitHub read surface.");
        return new TargetContext(repository, policy);
    }

    private async Task<TreeState> BuildTreeAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, TargetContext target, string? commitSha, int? maxDepth, CancellationToken cancellationToken)
    {
        if (projectEnvironmentId == Guid.Empty) throw InvalidPath("Project environment is required.");
        bool empty = target.Repository.HealthStatus == RepositoryConnectionHealthStates.Empty && target.Repository.DefaultBranchHeadSha is null;
        if (string.IsNullOrWhiteSpace(commitSha))
        {
            if (empty) return new TreeState(null, null, Array.Empty<RepositoryTreeEntry>());
            throw new RepositoryReadException(RepositoryReadErrorCodes.InvalidCommit, "An exact immutable commit SHA is required for repository reads.");
        }
        if (empty) throw new RepositoryReadException(RepositoryReadErrorCodes.InvalidCommit, "The repository is empty and has no commit SHA to read.");
        string exactCommit = NormalizeSha(commitSha);
        RepositoryProviderCommitTree root = await _provider.GetCommitTreeAsync(access.ProjectId, projectEnvironmentId, target.Repository.CredentialSecretReferenceId, target.Repository.Owner, target.Repository.Name, exactCommit, cancellationToken);
        var entries = new List<RepositoryTreeEntry>();
        var queue = new Queue<(string TreeSha, string Prefix)>();
        queue.Enqueue((root.TreeSha, string.Empty));
        while (queue.Count > 0)
        {
            (string treeSha, string parentPrefix) = queue.Dequeue();
            RepositoryProviderTree tree = await _provider.GetTreeAsync(access.ProjectId, projectEnvironmentId, target.Repository.CredentialSecretReferenceId, target.Repository.Owner, target.Repository.Name, treeSha, cancellationToken);
            if (tree.Truncated) throw TooLarge("GitHub returned a truncated tree. P031-S015 will add large-repository cache/index handling; S013 fails closed instead of pretending the tree is complete.");
            foreach (RepositoryProviderTreeEntry remote in tree.Entries)
            {
                string relative = NormalizePath(remote.Path, false);
                string fullPath = parentPrefix.Length == 0 ? relative : parentPrefix + "/" + relative;
                int depth = CountDepth(fullPath);
                if (maxDepth.HasValue && depth > maxDepth.Value) continue;
                string kind = MapKind(remote.Type, remote.Mode);
                if (entries.Count >= RepositoryReadLimits.MaxTreeEntries) throw TooLarge("Repository tree exceeds the 50000-entry S013 ceiling. P031-S015 will add large-repository cache/index handling.");
                var entry = new RepositoryTreeEntry(fullPath, GetName(fullPath), GetParent(fullPath), kind, remote.Mode, remote.Sha, remote.Size, depth, kind == RepositoryReadContentKinds.Symlink);
                entries.Add(entry);
                if (kind == RepositoryReadContentKinds.Directory && (!maxDepth.HasValue || depth < maxDepth.Value)) queue.Enqueue((remote.Sha, fullPath));
            }
        }
        return new TreeState(root.CommitSha, root.TreeSha, entries);
    }

    private async Task<(TreeState State, RepositoryTreeEntry Entry)> ResolveEntryAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, TargetContext target, string? commitSha, string path, CancellationToken cancellationToken)
    {
        string canonical = NormalizePath(path, false);
        TreeState state = await BuildTreeAsync(access, projectEnvironmentId, target, commitSha, null, cancellationToken);
        RepositoryTreeEntry? entry = state.Entries.SingleOrDefault(x => string.Equals(x.Path, canonical, StringComparison.Ordinal));
        if (entry is null) throw NotFound();
        return (state, entry);
    }

    private async Task<(TreeState State, RepositoryTreeEntry Entry)> ResolveReadableFileAsync(ProjectContextRequestAccess access, Guid projectEnvironmentId, TargetContext target, string? commitSha, string path, CancellationToken cancellationToken)
    {
        (TreeState state, RepositoryTreeEntry entry) = await ResolveEntryAsync(access, projectEnvironmentId, target, commitSha, path, cancellationToken);
        if (entry.Kind == RepositoryReadContentKinds.Symlink) throw new RepositoryReadException(RepositoryReadErrorCodes.SymlinkDenied, "Repository reads never follow symlinks. Read the canonical target path explicitly if it is separately authorized.");
        if (entry.Kind == RepositoryReadContentKinds.Directory) throw new RepositoryReadException(RepositoryReadErrorCodes.UnsupportedObject, "Requested repository path is a directory, not a file.");
        if (entry.Kind == RepositoryReadContentKinds.Submodule) throw new RepositoryReadException(RepositoryReadErrorCodes.UnsupportedObject, "Requested repository path is a submodule entry. Connect/read the target repository explicitly instead.");
        return (state, entry);
    }

    private static RepositoryFileMetadata Metadata(TargetContext target, TreeState state, RepositoryTreeEntry entry, string kind, bool isText, bool isBinary, bool canReadText, bool canReadBinary) => new(target.Repository.Id, target.Repository.FullName, state.CommitSha, entry.Path, kind, entry.Mode, entry.ObjectSha, entry.Size, isText, isBinary, canReadText, canReadBinary);
    private static RepositoryDirectorySummary Summarize(IEnumerable<RepositoryTreeEntry> entries)
    {
        int directories = 0, files = 0, symlinks = 0, submodules = 0;
        long bytes = 0;
        foreach (RepositoryTreeEntry entry in entries)
        {
            switch (entry.Kind)
            {
                case RepositoryReadContentKinds.Directory: directories++; break;
                case RepositoryReadContentKinds.File: files++; if (entry.Size.HasValue) bytes += entry.Size.Value; break;
                case RepositoryReadContentKinds.Symlink: symlinks++; break;
                case RepositoryReadContentKinds.Submodule: submodules++; break;
            }
        }
        return new RepositoryDirectorySummary(directories, files, symlinks, submodules, bytes);
    }

    private static string MapKind(string type, string mode) => type switch
    {
        "tree" => RepositoryReadContentKinds.Directory,
        "blob" when mode == "120000" => RepositoryReadContentKinds.Symlink,
        "blob" => RepositoryReadContentKinds.File,
        "commit" => RepositoryReadContentKinds.Submodule,
        _ => throw new RepositoryReadException(RepositoryReadErrorCodes.UnsupportedObject, "GitHub returned an unsupported tree object type.")
    };

    private static string NormalizeSha(string value)
    {
        string sha = value.Trim().ToLowerInvariant();
        if (sha.Length is not (40 or 64) || sha.Any(c => !Uri.IsHexDigit(c))) throw new RepositoryReadException(RepositoryReadErrorCodes.InvalidCommit, "An exact 40- or 64-character hexadecimal commit SHA is required.");
        return sha;
    }

    private static string NormalizePath(string? value, bool allowEmpty)
    {
        string path = value?.Trim() ?? string.Empty;
        if (path.Length == 0)
        {
            if (allowEmpty) return string.Empty;
            throw InvalidPath("A canonical repository path is required.");
        }
        if (path.Length > 1024 || path.StartsWith('/') || path.Contains('\\') || path.Contains('\0') || path.Contains('\r') || path.Contains('\n')) throw InvalidPath("Repository path must be a bounded canonical relative Git path.");
        string[] segments = path.Split('/', StringSplitOptions.None);
        if (segments.Any(x => x.Length == 0 || x is "." or "..")) throw InvalidPath("Repository path traversal and empty path segments are not allowed.");
        return string.Join('/', segments);
    }

    private static int CountDepth(string path) => path.Count(c => c == '/') + 1;
    private static string GetName(string path) { int index = path.LastIndexOf('/'); return index < 0 ? path : path[(index + 1)..]; }
    private static string GetParent(string path) { int index = path.LastIndexOf('/'); return index < 0 ? string.Empty : path[..index]; }
    private static string NormalizeNewlines(string value) => value.Replace("\r\n", "\n", StringComparison.Ordinal).Replace('\r', '\n');
    private static bool TryDecodeUtf8(byte[] bytes, out string text)
    {
        if (Array.IndexOf(bytes, (byte)0) >= 0) { text = string.Empty; return false; }
        try { text = StrictUtf8.GetString(bytes); return true; }
        catch (DecoderFallbackException) { text = string.Empty; return false; }
    }
    private static string MakeSnippet(string line, int matchIndex, int maxCharacters)
    {
        if (line.Length <= maxCharacters) return line;
        int start = Math.Max(0, matchIndex - maxCharacters / 3);
        int length = Math.Min(maxCharacters, line.Length - start);
        string result = line.Substring(start, length);
        if (start > 0) result = "..." + result;
        if (start + length < line.Length) result += "...";
        return result;
    }
    private static void RequireRead(ProjectContextRequestAccess access)
    {
        if (access.ProjectId == Guid.Empty || access.ActorUserId == Guid.Empty || !access.CanRead) throw new UnauthorizedAccessException("Project Context read access is required.");
    }
    private static RepositoryReadException NotFound() => new(RepositoryReadErrorCodes.NotFound, "Repository context or repository path was not found.");
    private static RepositoryReadException InvalidPath(string message) => new(RepositoryReadErrorCodes.InvalidPath, message);
    private static RepositoryReadException InvalidPaging(string message) => new(RepositoryReadErrorCodes.InvalidPaging, message);
    private static RepositoryReadException TooLarge(string message) => new(RepositoryReadErrorCodes.TooLarge, message);

    private sealed record TargetContext(ProjectContextRepository Repository, ProjectContextRepositoryPolicy Policy);
    private sealed record TreeState(string? CommitSha, string? RootTreeSha, IReadOnlyList<RepositoryTreeEntry> Entries);
}