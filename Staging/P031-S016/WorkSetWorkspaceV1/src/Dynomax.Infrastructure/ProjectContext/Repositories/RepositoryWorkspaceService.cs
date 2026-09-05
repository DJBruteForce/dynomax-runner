using System.Data;
using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;
using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Domain.ProjectContext;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class RepositoryWorkspaceService : IRepositoryWorkspaceService
{
    private const string Section = "Dynomax:RepositoryWorkspaces";
    private readonly DynomaxDbContext _db;
    private readonly IRepositoryGitCacheService _cache;
    private readonly IConfiguration _configuration;

    public RepositoryWorkspaceService(DynomaxDbContext db, IRepositoryGitCacheService cache, IConfiguration configuration)
    {
        _db = db;
        _cache = cache;
        _configuration = configuration;
    }

    public async Task<IReadOnlyList<RepositoryWorkSetSummary>> ListAsync(ProjectContextRequestAccess access, bool includeClosed, CancellationToken cancellationToken = default)
    {
        RequireRead(access);
        IQueryable<RepositoryWorkSet> query = _db.RepositoryWorkSets.AsNoTracking().Where(x => x.ProjectId == access.ProjectId);
        if (!includeClosed) query = query.Where(x => x.Status != "Closed");
        RepositoryWorkSet[] workSets = await query.OrderByDescending(x => x.UpdatedAtUtc).Take(100).ToArrayAsync(cancellationToken);
        return await ToSummariesAsync(workSets, cancellationToken);
    }

    public async Task<RepositoryWorkSetSummary> GetAsync(ProjectContextRequestAccess access, Guid workSetId, CancellationToken cancellationToken = default)
    {
        RequireRead(access);
        RepositoryWorkSet workSet = await LoadWorkSetAsync(access.ProjectId, workSetId, false, cancellationToken);
        return (await ToSummariesAsync(new[] { workSet }, cancellationToken))[0];
    }

    public async Task<RepositoryWorkSetSummary> CreateAsync(ProjectContextRequestAccess access, CreateRepositoryWorkSetCommand command, CancellationToken cancellationToken = default)
    {
        RequireManage(access);
        string title = Required(command.Title, 200, "Work-set title");
        string goal = Required(command.Goal, 4000, "Work-set goal");
        DateTime now = DateTime.UtcNow;
        var workSet = new RepositoryWorkSet(access.ProjectId, title, goal, access.ActorUserId, null, null, command.LinkedProjectIssueId, command.LinkedProductChangeId, command.LinkedTestingStepId, now);
        _db.RepositoryWorkSets.Add(workSet);
        await SaveAsync(cancellationToken);
        return (await ToSummariesAsync(new[] { workSet }, cancellationToken))[0];
    }

    public async Task<AddRepositoryWorkspaceResult> AddRepositoryAsync(ProjectContextRequestAccess access, Guid workSetId, Guid repositoryContextId, AddRepositoryWorkspaceCommand command, CancellationToken cancellationToken = default)
    {
        RequireManage(access);
        if (command.ProjectEnvironmentId == Guid.Empty) throw Invalid("Project environment is required.");
        string baseBranch = NormalizeBranch(command.BaseBranch, "Base branch");
        string? expectedSha = NormalizeOptionalSha(command.ExpectedBaseCommitSha);
        string? targetBranch = string.IsNullOrWhiteSpace(command.RemoteTargetBranch) ? null : NormalizeBranch(command.RemoteTargetBranch, "Remote target branch");
        RepositoryWorkSet workSet = await LoadWorkSetAsync(access.ProjectId, workSetId, true, cancellationToken);
        (ProjectContextRepository Repository, ProjectContextRepositoryPolicy Policy) pair = await LoadRepositoryAsync(access.ProjectId, repositoryContextId, cancellationToken);
        if (!pair.Policy.AllowWorkspace || !pair.Policy.AllowRead) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.PolicyDenied, "Repository workspace access is denied by effective repository policy.");
        EnsureBaseBranchAllowed(baseBranch, pair.Policy.AllowedBaseBranchPatternsJson);
        RepositoryGitCacheSnapshot cache = await EnsureCacheAsync(access.ProjectId, command.ProjectEnvironmentId, repositoryContextId, true, cancellationToken);
        string baseSha = await ResolveBaseShaAsync(cache.MirrorPath, baseBranch, cancellationToken);
        if (expectedSha is not null && !string.Equals(expectedSha, baseSha, StringComparison.OrdinalIgnoreCase))
            throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.StaleBase, "The requested base branch no longer resolves to the expected immutable commit SHA.");
        string workBranch = BuildWorkBranch(pair.Policy.AgentBranchPrefix, workSet.Id, pair.Repository.Id);
        if (string.Equals(workBranch, baseBranch, StringComparison.Ordinal) || string.Equals(workBranch, pair.Repository.DefaultBranch, StringComparison.Ordinal))
            throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.PolicyDenied, "Agent workspaces may not use the default/base branch as their writable work branch.");
        string storageKey = workSet.Id.ToString("N") + "/" + pair.Repository.Id.ToString("N");
        bool created = false;
        RepositoryWorkspace? workspace = await _db.RepositoryWorkspaces.SingleOrDefaultAsync(x => x.WorkSetId == workSet.Id && x.RepositoryContextId == pair.Repository.Id, cancellationToken);
        if (workspace is null)
        {
            var strategy = _db.Database.CreateExecutionStrategy();
            workspace = await strategy.ExecuteAsync(async () =>
            {
                await using var tx = await _db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
                RepositoryWorkspace? concurrent = await _db.RepositoryWorkspaces.SingleOrDefaultAsync(x => x.WorkSetId == workSet.Id && x.RepositoryContextId == pair.Repository.Id, cancellationToken);
                if (concurrent is not null) { await tx.CommitAsync(cancellationToken); return concurrent; }
                var value = new RepositoryWorkspace(workSet.Id, pair.Repository.Id, storageKey, baseBranch, baseSha, workBranch, targetBranch, access.ActorUserId, null, null, DateTime.UtcNow);
                _db.RepositoryWorkspaces.Add(value);
                await _db.SaveChangesAsync(cancellationToken);
                await tx.CommitAsync(cancellationToken);
                created = true;
                return value;
            });
        }
        if (!string.Equals(workspace.BaseBranch, baseBranch, StringComparison.Ordinal) || !string.Equals(workspace.BaseCommitSha, baseSha, StringComparison.OrdinalIgnoreCase) || !string.Equals(workspace.WorkBranch, workBranch, StringComparison.Ordinal))
            throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "This repository is already attached to the work-set with a different immutable base or work branch.");
        try
        {
            MaterializeResult materialized = await EnsureMaterializedAsync(cache, workspace, false, cancellationToken);
            if (materialized.Materialized || workspace.State == RepositoryWorkspaceStates.Preparing || workspace.State == RepositoryWorkspaceStates.Failed)
            {
                workspace.MarkMaterialized(baseSha, cache.LastFetchAtUtc.UtcDateTime, access.ActorUserId, DateTime.UtcNow);
                await SaveAsync(cancellationToken);
            }
            RepositoryWorkSetSummary summary = await GetAsync(access, workSet.Id, cancellationToken);
            RepositoryWorkspaceSummary ws = summary.Workspaces.Single(x => x.RepositoryContextId == repositoryContextId);
            return new AddRepositoryWorkspaceResult(summary, ws, created, materialized.Materialized, materialized.Rebuilt);
        }
        catch
        {
            workspace.MarkFailed(access.ActorUserId, DateTime.UtcNow);
            try { await _db.SaveChangesAsync(cancellationToken); } catch { }
            throw;
        }
    }

    public async Task<AddRepositoryWorkspaceResult> RebuildAsync(ProjectContextRequestAccess access, Guid workSetId, Guid repositoryContextId, RebuildRepositoryWorkspaceCommand command, CancellationToken cancellationToken = default)
    {
        RequireManage(access);
        if (command.ProjectEnvironmentId == Guid.Empty) throw Invalid("Project environment is required.");
        RepositoryWorkSet workSet = await LoadWorkSetAsync(access.ProjectId, workSetId, true, cancellationToken);
        (ProjectContextRepository Repository, ProjectContextRepositoryPolicy Policy) pair = await LoadRepositoryAsync(access.ProjectId, repositoryContextId, cancellationToken);
        if (!pair.Policy.AllowWorkspace || !pair.Policy.AllowRead) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.PolicyDenied, "Repository workspace access is denied by effective repository policy.");
        RepositoryWorkspace workspace = await _db.RepositoryWorkspaces.SingleOrDefaultAsync(x => x.WorkSetId == workSet.Id && x.RepositoryContextId == repositoryContextId, cancellationToken) ?? throw Missing();
        string? expected = NormalizeOptionalSha(command.ExpectedBaseCommitSha);
        if (expected is not null && !string.Equals(expected, workspace.BaseCommitSha, StringComparison.OrdinalIgnoreCase))
            throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.StaleBase, "The workspace immutable base SHA does not match the expected value.");
        if (workspace.State is not (RepositoryWorkspaceStates.Preparing or RepositoryWorkspaceStates.Clean or RepositoryWorkspaceStates.Failed))
            throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "Only Preparing, Clean or Failed workspace material may be rebuilt automatically.");
        RepositoryGitCacheSnapshot cache = await EnsureCacheAsync(access.ProjectId, command.ProjectEnvironmentId, repositoryContextId, false, cancellationToken);
        if (!await CommitExistsAsync(cache.MirrorPath, workspace.BaseCommitSha, cancellationToken))
        {
            cache = await EnsureCacheAsync(access.ProjectId, command.ProjectEnvironmentId, repositoryContextId, true, cancellationToken);
            if (!await CommitExistsAsync(cache.MirrorPath, workspace.BaseCommitSha, cancellationToken)) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.BaseRefNotFound, "The immutable workspace base commit is not available from the repository.");
        }
        workspace.ResetPreparing(access.ActorUserId, DateTime.UtcNow);
        await SaveAsync(cancellationToken);
        try
        {
            MaterializeResult materialized = await EnsureMaterializedAsync(cache, workspace, true, cancellationToken);
            workspace.MarkMaterialized(workspace.BaseCommitSha, cache.LastFetchAtUtc.UtcDateTime, access.ActorUserId, DateTime.UtcNow);
            await SaveAsync(cancellationToken);
            RepositoryWorkSetSummary summary = await GetAsync(access, workSet.Id, cancellationToken);
            return new AddRepositoryWorkspaceResult(summary, summary.Workspaces.Single(x => x.RepositoryContextId == repositoryContextId), false, materialized.Materialized, true);
        }
        catch
        {
            workspace.MarkFailed(access.ActorUserId, DateTime.UtcNow);
            try { await _db.SaveChangesAsync(cancellationToken); } catch { }
            throw;
        }
    }

    public async Task<RepositoryWorkSetSummary> CloseAsync(ProjectContextRequestAccess access, Guid workSetId, CloseRepositoryWorkSetCommand command, CancellationToken cancellationToken = default)
    {
        RequireManage(access);
        RepositoryWorkSet workSet = await LoadWorkSetAsync(access.ProjectId, workSetId, true, cancellationToken);
        ApplyExpectedRowVersion(workSet, command.ExpectedConcurrencyToken);
        RepositoryWorkspace[] workspaces = await _db.RepositoryWorkspaces.Where(x => x.WorkSetId == workSet.Id).ToArrayAsync(cancellationToken);
        Settings settings = ReadSettings();
        foreach (RepositoryWorkspace workspace in workspaces)
        {
            if (workspace.State is RepositoryWorkspaceStates.Modified or RepositoryWorkspaceStates.Conflicted or RepositoryWorkspaceStates.Rebasing)
                throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "A modified/conflicted/rebasing workspace must be resolved before the work-set can be cleaned up.");
            string path = WorkspacePath(settings, workspace.StorageKey);
            try { DeleteDirectory(path); } catch (IOException) { throw Materialization("Workspace material could not be removed safely."); } catch (UnauthorizedAccessException) { throw Materialization("Workspace material could not be removed safely."); }
            workspace.MarkClosed(access.ActorUserId, DateTime.UtcNow);
        }
        workSet.SetStatus("Closed", DateTime.UtcNow);
        await SaveAsync(cancellationToken);
        return await GetAsync(access, workSet.Id, cancellationToken);
    }

    private async Task<RepositoryGitCacheSnapshot> EnsureCacheAsync(Guid projectId, Guid environmentId, Guid repositoryContextId, bool forceRefresh, CancellationToken cancellationToken)
    {
        try { return await _cache.EnsureAsync(projectId, environmentId, repositoryContextId, forceRefresh, cancellationToken); }
        catch (RepositoryGitCacheException ex) { throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.MaterializationFailed, ex.Message); }
    }

    private async Task<MaterializeResult> EnsureMaterializedAsync(RepositoryGitCacheSnapshot cache, RepositoryWorkspace workspace, bool forceRebuild, CancellationToken cancellationToken)
    {
        Settings settings = ReadSettings();
        string path = WorkspacePath(settings, workspace.StorageKey);
        if (Directory.Exists(path))
        {
            if (!forceRebuild && await IsHealthyAsync(path, workspace, cache.RemoteUrl, settings.GitTimeout, cancellationToken)) return new MaterializeResult(false, false);
            if (!forceRebuild) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "Workspace material exists but does not match the durable pinned workspace identity. Use explicit rebuild after confirming it is safe to discard.");
            DeleteDirectory(path);
        }
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        GitResult clone = await RunGitAsync(new[] { "clone", "--no-local", "--no-checkout", "--", cache.MirrorPath, path }, settings.GitTimeout, cancellationToken);
        if (clone.ExitCode != 0) { DeleteDirectory(path); throw Materialization("Workspace clone from the rebuildable repository cache failed."); }
        GitResult remote = await RunGitAsync(new[] { "-C", path, "remote", "set-url", "origin", cache.RemoteUrl }, settings.GitTimeout, cancellationToken);
        if (remote.ExitCode != 0) { DeleteDirectory(path); throw Materialization("Workspace credential-free remote configuration failed."); }
        GitResult checkout = await RunGitAsync(new[] { "-C", path, "checkout", "-b", workspace.WorkBranch, workspace.BaseCommitSha }, settings.GitTimeout, cancellationToken);
        if (checkout.ExitCode != 0) { DeleteDirectory(path); throw Materialization("Workspace branch creation at the immutable base commit failed."); }
        if (!await IsHealthyAsync(path, workspace, cache.RemoteUrl, settings.GitTimeout, cancellationToken)) { DeleteDirectory(path); throw Materialization("Workspace verification failed after materialization."); }
        string configPath = Path.Combine(path, ".git", "config");
        string config = File.Exists(configPath) ? await File.ReadAllTextAsync(configPath, cancellationToken) : string.Empty;
        foreach (string marker in new[] { "github_pat_", "x-access-token", "Authorization:", "Bearer " })
            if (config.Contains(marker, StringComparison.OrdinalIgnoreCase)) { DeleteDirectory(path); throw Materialization("Workspace Git configuration contained forbidden credential material."); }
        return new MaterializeResult(true, forceRebuild);
    }

    private static async Task<bool> IsHealthyAsync(string path, RepositoryWorkspace workspace, string expectedRemote, TimeSpan timeout, CancellationToken cancellationToken)
    {
        GitResult head = await RunGitAsync(new[] { "-C", path, "rev-parse", "HEAD" }, timeout, cancellationToken);
        GitResult branch = await RunGitAsync(new[] { "-C", path, "branch", "--show-current" }, timeout, cancellationToken);
        GitResult remote = await RunGitAsync(new[] { "-C", path, "remote", "get-url", "origin" }, timeout, cancellationToken);
        return head.ExitCode == 0 && branch.ExitCode == 0 && remote.ExitCode == 0 && string.Equals(head.Output.Trim(), workspace.BaseCommitSha, StringComparison.OrdinalIgnoreCase) && string.Equals(branch.Output.Trim(), workspace.WorkBranch, StringComparison.Ordinal) && string.Equals(remote.Output.Trim(), expectedRemote, StringComparison.Ordinal);
    }

    private async Task<string> ResolveBaseShaAsync(string mirrorPath, string baseBranch, CancellationToken cancellationToken)
    {
        GitResult result = await RunGitAsync(new[] { "--git-dir", mirrorPath, "rev-parse", "--verify", $"refs/heads/{baseBranch}^{{commit}}" }, ReadSettings().GitTimeout, cancellationToken);
        if (result.ExitCode != 0) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.BaseRefNotFound, "The requested base branch is unavailable. Empty repositories cannot create a workspace until a commit exists.");
        return NormalizeSha(result.Output.Trim());
    }

    private async Task<bool> CommitExistsAsync(string mirrorPath, string sha, CancellationToken cancellationToken)
    {
        GitResult result = await RunGitAsync(new[] { "--git-dir", mirrorPath, "cat-file", "-e", sha + "^{commit}" }, ReadSettings().GitTimeout, cancellationToken);
        return result.ExitCode == 0;
    }

    private async Task<(ProjectContextRepository Repository, ProjectContextRepositoryPolicy Policy)> LoadRepositoryAsync(Guid projectId, Guid repositoryContextId, CancellationToken cancellationToken)
    {
        Guid? sourceId = await _db.ProjectContextSources.AsNoTracking().Where(x => x.ProjectId == projectId && x.SourceType == ProjectContextSourceTypes.GitRepositories && x.IsActive).Select(x => (Guid?)x.Id).SingleOrDefaultAsync(cancellationToken);
        if (!sourceId.HasValue) throw Missing();
        ProjectContextRepository? repository = await _db.ProjectContextRepositories.AsNoTracking().SingleOrDefaultAsync(x => x.Id == repositoryContextId && x.SourceId == sourceId.Value && x.IsActive, cancellationToken);
        if (repository is null) throw Missing();
        ProjectContextRepositoryPolicy policy = await _db.ProjectContextRepositoryPolicies.AsNoTracking().SingleAsync(x => x.RepositoryContextId == repositoryContextId, cancellationToken);
        return (repository, policy);
    }

    private async Task<RepositoryWorkSet> LoadWorkSetAsync(Guid projectId, Guid workSetId, bool requireActive, CancellationToken cancellationToken)
    {
        if (projectId == Guid.Empty || workSetId == Guid.Empty) throw Missing();
        RepositoryWorkSet? workSet = await _db.RepositoryWorkSets.SingleOrDefaultAsync(x => x.Id == workSetId && x.ProjectId == projectId && (!requireActive || x.Status == "Active"), cancellationToken);
        return workSet ?? throw Missing();
    }

    private async Task<IReadOnlyList<RepositoryWorkSetSummary>> ToSummariesAsync(IReadOnlyList<RepositoryWorkSet> workSets, CancellationToken cancellationToken)
    {
        if (workSets.Count == 0) return Array.Empty<RepositoryWorkSetSummary>();
        Guid[] ids = workSets.Select(x => x.Id).ToArray();
        RepositoryWorkspace[] workspaces = await _db.RepositoryWorkspaces.AsNoTracking().Where(x => ids.Contains(x.WorkSetId)).OrderBy(x => x.CreatedAtUtc).ToArrayAsync(cancellationToken);
        Guid[] repoIds = workspaces.Select(x => x.RepositoryContextId).Distinct().ToArray();
        Dictionary<Guid, string> names = repoIds.Length == 0 ? new() : await _db.ProjectContextRepositories.AsNoTracking().Where(x => repoIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, x => x.FullName, cancellationToken);
        return workSets.Select(w => new RepositoryWorkSetSummary(w.Id, w.Title, w.Goal, w.Status, w.OwnerUserId, w.LinkedProjectIssueId, w.LinkedProductChangeId, w.LinkedTestingStepId, w.CreatedAtUtc, w.UpdatedAtUtc, w.ExpiresAtUtc, Convert.ToBase64String(w.RowVersion), workspaces.Where(x => x.WorkSetId == w.Id).Select(x => new RepositoryWorkspaceSummary(x.Id, x.RepositoryContextId, names.GetValueOrDefault(x.RepositoryContextId, "Unknown repository"), x.BaseBranch, x.BaseCommitSha, x.WorkBranch, x.CurrentCommitSha, x.LastPushedCommitSha, x.RemoteTargetBranch, x.State, x.LastFetchedAtUtc, x.LastSyncedAtUtc, Convert.ToBase64String(x.RowVersion))).ToArray())).ToArray();
    }

    private static void EnsureBaseBranchAllowed(string branch, string patternsJson)
    {
        string[] patterns;
        try { patterns = JsonSerializer.Deserialize<string[]>(patternsJson) ?? Array.Empty<string>(); } catch (JsonException) { patterns = Array.Empty<string>(); }
        if (patterns.Length == 0) return;
        if (!patterns.Any(pattern => GlobMatches(branch, pattern))) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.PolicyDenied, "The requested base branch is outside the repository policy allow-list.");
    }

    private static bool GlobMatches(string value, string pattern)
    {
        string regex = "^" + Regex.Escape(pattern).Replace("\\*", ".*").Replace("\\?", ".") + "$";
        return Regex.IsMatch(value, regex, RegexOptions.CultureInvariant);
    }

    private static string BuildWorkBranch(string prefix, Guid workSetId, Guid repositoryContextId)
    {
        string normalized = string.IsNullOrWhiteSpace(prefix) ? "dynomax/" : prefix.Trim();
        if (!normalized.EndsWith('/')) normalized += "/";
        return NormalizeBranch(normalized + "ws-" + workSetId.ToString("N")[..12] + "-" + repositoryContextId.ToString("N")[..12], "Work branch");
    }

    private Settings ReadSettings()
    {
        string root = _configuration[$"{Section}:RootPath"] ?? Path.Combine(Path.GetTempPath(), "Dynomax", "RepositoryWorkspaces");
        root = Path.GetFullPath(root);
        int seconds = int.TryParse(_configuration[$"{Section}:GitTimeoutSeconds"], out int parsed) ? Math.Clamp(parsed, 10, 1800) : 180;
        return new Settings(root, TimeSpan.FromSeconds(seconds));
    }

    private static string WorkspacePath(Settings settings, string storageKey)
    {
        string path = Path.GetFullPath(Path.Combine(settings.RootPath, storageKey.Replace('/', Path.DirectorySeparatorChar)));
        string root = settings.RootPath.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw Materialization("Workspace storage key escaped the configured root.");
        return path;
    }

    private static async Task<GitResult> RunGitAsync(string[] args, TimeSpan timeout, CancellationToken cancellationToken)
    {
        var startInfo = new ProcessStartInfo("git") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (string arg in args) startInfo.ArgumentList.Add(arg);
        startInfo.Environment["GIT_TERMINAL_PROMPT"] = "0";
        startInfo.Environment["GCM_INTERACTIVE"] = "Never";
        using var process = new Process { StartInfo = startInfo };
        try
        {
            if (!process.Start()) return new GitResult(127, string.Empty);
            var stdout = process.StandardOutput.ReadToEndAsync(cancellationToken);
            var stderr = process.StandardError.ReadToEndAsync(cancellationToken);
            using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            linked.CancelAfter(timeout);
            await process.WaitForExitAsync(linked.Token);
            string output = await stdout;
            _ = await stderr;
            return new GitResult(process.ExitCode, output);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            try { if (!process.HasExited) process.Kill(true); } catch { }
            return new GitResult(124, string.Empty);
        }
        catch (System.ComponentModel.Win32Exception) { return new GitResult(127, string.Empty); }
    }

    private void ApplyExpectedRowVersion(RepositoryWorkSet workSet, string token)
    {
        if (string.IsNullOrWhiteSpace(token)) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "A work-set concurrency token is required.");
        byte[] value;
        try { value = Convert.FromBase64String(token); } catch (FormatException) { throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "The work-set concurrency token is invalid."); }
        if (value.Length == 0) throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "The work-set concurrency token is invalid.");
        _db.Entry(workSet).Property(x => x.RowVersion).OriginalValue = value;
    }

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        try { await _db.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateConcurrencyException) { throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "Repository work-set/workspace changed since it was read. Refresh and retry."); }
        catch (DbUpdateException) { throw new RepositoryWorkspaceException(RepositoryWorkspaceErrorCodes.Conflict, "Repository workspace identity conflicts with existing durable work-set state."); }
    }

    private static string Required(string? value, int max, string label) { string normalized = value?.Trim() ?? string.Empty; if (normalized.Length == 0 || normalized.Length > max) throw Invalid(label + " is required and must remain within its bounded length."); return normalized; }
    private static string NormalizeBranch(string? value, string label)
    {
        string branch = value?.Trim() ?? string.Empty;
        const string forbidden = "~^:?*[\\";
        if (branch.Length == 0 || branch.Length > 255 || branch.StartsWith('-') || branch.StartsWith('/') || branch.EndsWith('/') || branch.EndsWith('.') || branch.EndsWith(".lock", StringComparison.OrdinalIgnoreCase) || branch.Contains("..", StringComparison.Ordinal) || branch.Contains("//", StringComparison.Ordinal) || branch.Any(c => char.IsControl(c) || char.IsWhiteSpace(c) || forbidden.Contains(c))) throw Invalid(label + " is invalid.");
        return branch;
    }
    private static string NormalizeSha(string value) { string normalized = value.Trim().ToLowerInvariant(); if (normalized.Length is not (40 or 64) || normalized.Any(c => !Uri.IsHexDigit(c))) throw Invalid("Git SHA is invalid."); return normalized; }
    private static string? NormalizeOptionalSha(string? value) => string.IsNullOrWhiteSpace(value) ? null : NormalizeSha(value);
    private static void RequireRead(ProjectContextRequestAccess access) { if (access.ProjectId == Guid.Empty || access.ActorUserId == Guid.Empty || !access.CanRead) throw new UnauthorizedAccessException("Project Context read access is required."); }
    private static void RequireManage(ProjectContextRequestAccess access) { RequireRead(access); if (!access.CanManage) throw new UnauthorizedAccessException("Project Context management access is required."); }
    private static RepositoryWorkspaceException Missing() => new(RepositoryWorkspaceErrorCodes.NotFound, "Repository work-set or workspace was not found.");
    private static RepositoryWorkspaceException Invalid(string message) => new(RepositoryWorkspaceErrorCodes.InvalidInput, message);
    private static RepositoryWorkspaceException Materialization(string message) => new(RepositoryWorkspaceErrorCodes.MaterializationFailed, message);
    private static void DeleteDirectory(string path) { if (!Directory.Exists(path)) return; foreach (string file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories)) { try { File.SetAttributes(file, FileAttributes.Normal); } catch { } } Directory.Delete(path, true); }
    private sealed record Settings(string RootPath, TimeSpan GitTimeout);
    private sealed record GitResult(int ExitCode, string Output);
    private sealed record MaterializeResult(bool Materialized, bool Rebuilt);
}