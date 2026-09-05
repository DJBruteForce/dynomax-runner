using System.ComponentModel.DataAnnotations;
using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Dynomax.Portal.Pages.Projects.Context;

public sealed partial class IndexModel
{
    public const string RepositoryCollectionName = "Repositories";
    private readonly IRepositoryConnectionService _repositoryConnections;
    private readonly IRepositoryContextPresentationService _repositoryPresentation;

    public IReadOnlyList<RepositoryContextPresentationRow> RepositoryRows { get; private set; } = [];
    public IReadOnlyList<RepositoryContextPresentationRow> RepositoryBrowseRows { get; private set; } = [];
    public IReadOnlyList<RepositoryCredentialReferenceOption> RepositoryCredentialOptions { get; private set; } = [];
    public RepositoryContextPresentationRow? SelectedRepository { get; private set; }
    public bool IsRepositoryBrowse { get; private set; }
    public string RepositorySort { get; private set; } = "Name";

    [BindProperty] public RepositoryConnectForm RepositoryConnectInput { get; set; } = new();
    [BindProperty] public RepositoryEditForm RepositoryEditInput { get; set; } = new();

    public async Task<IActionResult> OnPostConnectRepositoryAsync(Guid projectId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanManage) return Forbid();
        RepositoryCredentialReferenceOption? credential = await ResolveCredentialAsync(access, RepositoryConnectInput.CredentialSecretReferenceId, cancellationToken);
        if (credential is null) return RepositoryError(projectId, "Select an active protected GitHub credential reference.");
        try
        {
            ConnectRepositoryResult result = await _repositoryConnections.ConnectAsync(access, new ConnectRepositoryCommand(
                credential.ProjectEnvironmentId,
                RepositoryConnectInput.RepositoryUrl ?? string.Empty,
                credential.SecretReferenceId,
                RepositoryConnectInput.Role,
                RepositoryConnectInput.Purpose,
                SplitTags(RepositoryConnectInput.Tags)), cancellationToken);
            TempData["Success"] = result.Created ? $"Connected {result.Connection.FullName}." : result.Reactivated ? $"Reconnected {result.Connection.FullName}." : $"{result.Connection.FullName} is already connected.";
            return RedirectToPage(new { projectId, category = RepositoryCollectionName, repositoryContextId = result.Connection.RepositoryContextId });
        }
        catch (Exception exception) when (exception is RepositoryConnectionException or RepositoryProviderException or ArgumentException or InvalidOperationException)
        {
            return RepositoryError(projectId, exception.Message);
        }
    }

    public async Task<IActionResult> OnPostRefreshRepositoryAsync(Guid projectId, Guid repositoryContextId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanManage) return Forbid();
        try
        {
            RepositoryContextPresentationRow? row = (await _repositoryPresentation.ListAsync(access, false, cancellationToken)).FirstOrDefault(item => item.Connection.RepositoryContextId == repositoryContextId);
            if (row?.Credential is null) return RepositoryError(projectId, "The repository credential reference is unavailable.");
            RepositoryConnectionSummary refreshed = await _repositoryConnections.RefreshAsync(access, row.Credential.ProjectEnvironmentId, repositoryContextId, cancellationToken);
            TempData["Success"] = $"Refreshed {refreshed.FullName}.";
            return RedirectToPage(new { projectId, category = RepositoryCollectionName, repositoryContextId });
        }
        catch (Exception exception) when (exception is RepositoryConnectionException or RepositoryProviderException or InvalidOperationException)
        {
            return RepositoryError(projectId, exception.Message);
        }
    }

    public async Task<IActionResult> OnPostDisconnectRepositoryAsync(Guid projectId, Guid repositoryContextId, string expectedConcurrencyToken, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanManage) return Forbid();
        try
        {
            RepositoryConnectionSummary disconnected = await _repositoryConnections.DisconnectAsync(access, repositoryContextId, expectedConcurrencyToken, cancellationToken);
            TempData["Success"] = $"Disconnected {disconnected.FullName}. Repository history was preserved.";
            return RedirectToPage(new { projectId, category = RepositoryCollectionName });
        }
        catch (Exception exception) when (exception is RepositoryConnectionException or InvalidOperationException)
        {
            return RepositoryError(projectId, exception.Message);
        }
    }

    public async Task<IActionResult> OnPostUpdateRepositoryAsync(Guid projectId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanManage) return Forbid();
        RepositoryCredentialReferenceOption? credential = await ResolveCredentialAsync(access, RepositoryEditInput.CredentialSecretReferenceId, cancellationToken);
        if (credential is null) return RepositoryError(projectId, "Select an active protected GitHub credential reference.");
        try
        {
            RepositoryPolicyUpdate policy = new(
                RepositoryEditInput.AllowRead,
                RepositoryEditInput.AllowWorkspace,
                RepositoryEditInput.AllowCommitPush,
                RepositoryEditInput.AllowPullRequest,
                false, false, false, false, false,
                RepositoryEditInput.RequirePullRequestForDefaultBranch,
                SplitPatterns(RepositoryEditInput.AllowedTargetBranchPatterns),
                SplitPatterns(RepositoryEditInput.AllowedBaseBranchPatterns),
                RepositoryEditInput.AgentBranchPrefix ?? "dynomax/");
            RepositoryConnectionSummary updated = await _repositoryConnections.UpdateAsync(access, RepositoryEditInput.RepositoryContextId, new UpdateRepositoryConnectionCommand(
                credential.ProjectEnvironmentId,
                credential.SecretReferenceId,
                RepositoryEditInput.Role,
                RepositoryEditInput.Purpose,
                SplitTags(RepositoryEditInput.Tags),
                policy,
                RepositoryEditInput.ExpectedConcurrencyToken ?? string.Empty), cancellationToken);
            TempData["Success"] = $"Updated {updated.FullName} repository context.";
            return RedirectToPage(new { projectId, category = RepositoryCollectionName, repositoryContextId = updated.RepositoryContextId });
        }
        catch (Exception exception) when (exception is RepositoryConnectionException or RepositoryProviderException or ArgumentException or InvalidOperationException)
        {
            return RepositoryError(projectId, exception.Message);
        }
    }

    private async Task LoadRepositoryUiAsync(
        ProjectContextRequestAccess access,
        string? category,
        Guid? repositoryContextId,
        string? search,
        string? filter,
        string? sort,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        RepositoryRows = await _repositoryPresentation.ListAsync(access, ShowDiagnostics, cancellationToken);
        RepositoryCredentialOptions = await _repositoryPresentation.ListCredentialOptionsAsync(access, cancellationToken);
        var repositoryNav = new ProjectContextCollectionNavItem(RepositoryCollectionName, RepositoryRows.Count, 0L);
        CollectionNavigation = new[] { repositoryNav }.Concat(CollectionNavigation.Where(item => !string.Equals(item.Name, RepositoryCollectionName, StringComparison.OrdinalIgnoreCase))).ToArray();

        IsRepositoryBrowse = string.Equals(category, RepositoryCollectionName, StringComparison.OrdinalIgnoreCase)
            || (string.IsNullOrWhiteSpace(category) && Resources.Count == 0 && RepositoryRows.Count > 0);
        if (!IsRepositoryBrowse) return;

        BrowseCategory = RepositoryCollectionName;
        BrowsePath = string.Empty;
        SearchQuery = search?.Trim() ?? string.Empty;
        Filter = string.IsNullOrWhiteSpace(filter) ? "All" : filter.Trim();
        RepositorySort = string.IsNullOrWhiteSpace(sort) ? "Name" : sort.Trim();
        PageSize = pageSize is 10 or 20 or 50 or 100 ? pageSize : 20;
        SelectedResource = null;
        SelectedPreviewText = null;

        IEnumerable<RepositoryContextPresentationRow> rows = RepositoryRows;
        if (!string.IsNullOrWhiteSpace(SearchQuery))
            rows = rows.Where(row => Contains(row.Connection.FullName, SearchQuery)
                                     || Contains(row.Connection.Role, SearchQuery)
                                     || Contains(row.Connection.Purpose, SearchQuery)
                                     || Contains(row.Connection.HealthStatus, SearchQuery)
                                     || Contains(row.Connection.Visibility, SearchQuery)
                                     || row.Connection.Tags.Any(tag => Contains(tag, SearchQuery)));

        rows = Filter.ToLowerInvariant() switch
        {
            "healthy" => rows.Where(row => string.Equals(row.Connection.HealthStatus, RepositoryConnectionHealthStates.Healthy, StringComparison.OrdinalIgnoreCase)),
            "empty" => rows.Where(row => string.Equals(row.Connection.HealthStatus, RepositoryConnectionHealthStates.Empty, StringComparison.OrdinalIgnoreCase)),
            "error" => rows.Where(row => string.Equals(row.Connection.HealthStatus, RepositoryConnectionHealthStates.Error, StringComparison.OrdinalIgnoreCase)),
            "private" => rows.Where(row => string.Equals(row.Connection.Visibility, "private", StringComparison.OrdinalIgnoreCase)),
            "archived" => rows.Where(row => row.Connection.IsArchived),
            _ => rows
        };

        rows = RepositorySort.ToLowerInvariant() switch
        {
            "role" => rows.OrderBy(row => row.Connection.Role ?? string.Empty, StringComparer.OrdinalIgnoreCase).ThenBy(row => row.Connection.FullName, StringComparer.OrdinalIgnoreCase),
            "health" => rows.OrderBy(row => row.Connection.HealthStatus, StringComparer.OrdinalIgnoreCase).ThenBy(row => row.Connection.FullName, StringComparer.OrdinalIgnoreCase),
            "refreshed" => rows.OrderByDescending(row => row.Connection.LastRefreshedAtUtc ?? DateTime.MinValue).ThenBy(row => row.Connection.FullName, StringComparer.OrdinalIgnoreCase),
            _ => rows.OrderBy(row => row.Connection.FullName, StringComparer.OrdinalIgnoreCase)
        };

        RepositoryContextPresentationRow[] materialized = rows.ToArray();
        BrowseTotal = materialized.Length;
        PageNumber = Math.Clamp(page, 1, Math.Max(1, (int)Math.Ceiling(BrowseTotal / (double)PageSize)));
        RepositoryBrowseRows = materialized.Skip((PageNumber - 1) * PageSize).Take(PageSize).ToArray();
        SelectedRepository = repositoryContextId is Guid id ? RepositoryRows.FirstOrDefault(row => row.Connection.RepositoryContextId == id) : null;
        RepositoryConnectInput.CredentialSecretReferenceId ??= RepositoryCredentialOptions.FirstOrDefault()?.SecretReferenceId;

        if (SelectedRepository is not null)
        {
            RepositoryConnectionSummary connection = SelectedRepository.Connection;
            RepositoryEditInput = new RepositoryEditForm
            {
                RepositoryContextId = connection.RepositoryContextId,
                CredentialSecretReferenceId = connection.CredentialSecretReferenceId,
                Role = connection.Role,
                Purpose = connection.Purpose,
                Tags = string.Join(", ", connection.Tags),
                AllowRead = connection.Policy.AllowRead,
                AllowWorkspace = connection.Policy.AllowWorkspace,
                AllowCommitPush = connection.Policy.AllowCommitPush,
                AllowPullRequest = connection.Policy.AllowPullRequest,
                RequirePullRequestForDefaultBranch = connection.Policy.RequirePullRequestForDefaultBranch,
                AllowedTargetBranchPatterns = string.Join(", ", connection.Policy.AllowedTargetBranchPatterns),
                AllowedBaseBranchPatterns = string.Join(", ", connection.Policy.AllowedBaseBranchPatterns),
                AgentBranchPrefix = connection.Policy.AgentBranchPrefix,
                ExpectedConcurrencyToken = connection.ConcurrencyToken
            };
        }
    }

    private async Task<RepositoryCredentialReferenceOption?> ResolveCredentialAsync(ProjectContextRequestAccess access, Guid? secretReferenceId, CancellationToken cancellationToken)
    {
        if (secretReferenceId is null || secretReferenceId == Guid.Empty) return null;
        return (await _repositoryPresentation.ListCredentialOptionsAsync(access, cancellationToken)).FirstOrDefault(item => item.SecretReferenceId == secretReferenceId.Value);
    }

    private IActionResult RepositoryError(Guid projectId, string message)
    {
        TempData["Error"] = message;
        return RedirectToPage(new { projectId, category = RepositoryCollectionName });
    }

    private static bool Contains(string? value, string search) => !string.IsNullOrWhiteSpace(value) && value.Contains(search, StringComparison.OrdinalIgnoreCase);
    private static string[] SplitPatterns(string? value) => string.IsNullOrWhiteSpace(value) ? [] : value.Split([',', ';', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    public sealed class RepositoryConnectForm
    {
        [Required, StringLength(500)] public string? RepositoryUrl { get; set; }
        public Guid? CredentialSecretReferenceId { get; set; }
        [StringLength(100)] public string? Role { get; set; }
        [StringLength(1000)] public string? Purpose { get; set; }
        [StringLength(1000)] public string? Tags { get; set; }
    }

    public sealed class RepositoryEditForm
    {
        public Guid RepositoryContextId { get; set; }
        public Guid? CredentialSecretReferenceId { get; set; }
        [StringLength(100)] public string? Role { get; set; }
        [StringLength(1000)] public string? Purpose { get; set; }
        [StringLength(1000)] public string? Tags { get; set; }
        public bool AllowRead { get; set; }
        public bool AllowWorkspace { get; set; }
        public bool AllowCommitPush { get; set; }
        public bool AllowPullRequest { get; set; }
        public bool RequirePullRequestForDefaultBranch { get; set; } = true;
        [StringLength(2000)] public string? AllowedTargetBranchPatterns { get; set; }
        [StringLength(2000)] public string? AllowedBaseBranchPatterns { get; set; }
        [StringLength(100)] public string? AgentBranchPrefix { get; set; } = "dynomax/";
        [Required] public string? ExpectedConcurrencyToken { get; set; }
    }
}