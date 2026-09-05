using System.ComponentModel.DataAnnotations;
using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Application.Projects;
using Dynomax.Application.Security;
using Dynomax.Domain.ProjectContext;
using Dynomax.Portal.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Dynomax.Portal.Pages.Projects.Context;

[Authorize(Policy = SystemPermissions.ProjectContextRead)]
[RequestSizeLimit(ProjectContextLimits.MaxRequestBytes)]
[RequestFormLimits(MultipartBodyLengthLimit = ProjectContextLimits.MaxRequestBytes)]
public sealed partial class IndexModel : PageModel
{
    private static readonly string[] DefaultCollections =
    [
        "Source Code",
        "Documentation",
        "Architecture",
        "Requirements",
        "Reference Files",
        "Design Assets",
        "Configuration"
    ];

    private readonly IProjectRepository _projects;
    private readonly IProjectAccessService _projectAccess;
    private readonly IProjectContextService _context;
    private readonly IAuthorizationService _authorization;
    private readonly IWebHostEnvironment _environment;

    public IndexModel(
        IProjectRepository projects,
        IProjectAccessService projectAccess,
        IProjectContextService context,
        IRepositoryConnectionService repositoryConnections,
        IRepositoryContextPresentationService repositoryPresentation,
        IAuthorizationService authorization,
        IWebHostEnvironment environment)
    {
        _projects = projects;
        _projectAccess = projectAccess;
        _context = context;
        _repositoryConnections = repositoryConnections;
        _repositoryPresentation = repositoryPresentation;
        _authorization = authorization;
        _environment = environment;
    }

    public ProjectDetails Project { get; private set; } = null!;
    public ProjectContextCapabilities Capabilities { get; private set; } = null!;
    public IReadOnlyList<ProjectContextResourceSummary> Resources { get; private set; } = [];
    public IReadOnlyList<ProjectContextCategorySummary> Categories { get; private set; } = [];
    public IReadOnlyList<ProjectContextCollectionNavItem> CollectionNavigation { get; private set; } = [];
    public IReadOnlyList<ProjectContextBrowseEntry> BrowseEntries { get; private set; } = [];
    public IReadOnlyList<ProjectContextActivityRow> RecentActivity { get; private set; } = [];
    public IReadOnlyList<ProjectContextStorageSlice> StorageBreakdown { get; private set; } = [];
    public string? BrowseCategory { get; private set; }
    public string BrowsePath { get; private set; } = string.Empty;
    public string SearchQuery { get; private set; } = string.Empty;
    public string Filter { get; private set; } = "All";
    public int PageNumber { get; private set; } = 1;
    public int PageSize { get; private set; } = 20;
    public int BrowseTotal { get; private set; }
    public int PageCount => Math.Max(1, (int)Math.Ceiling(BrowseTotal / (double)Math.Max(1, PageSize)));
    public ProjectContextResourceDetails? SelectedResource { get; private set; }
    public string? SelectedPreviewText { get; private set; }
    public ProjectContextArchiveEntryPage? ArchiveEntries { get; private set; }
    public Guid? ArchiveVersionId { get; private set; }
    public bool ShowDiagnostics { get; private set; }
    public bool CanUpload { get; private set; }
    public bool CanManage { get; private set; }
    public bool CanImportLocalFolder { get; private set; }
    public long CurrentStorageBytes { get; private set; }
    public DateTime? LastImportUtc { get; private set; }

    [BindProperty] public UploadInput Input { get; set; } = new();
    [BindProperty] public FolderImportInput FolderInput { get; set; } = new();

    public async Task<IActionResult> OnGetAsync(
        Guid projectId,
        string? category,
        string? path,
        Guid? resourceId,
        Guid? repositoryContextId,
        Guid? archiveVersionId,
        bool showDiagnostics,
        string? q,
        string? filter,
        string? sort,
        int page = 1,
        int pageSize = 20,
        CancellationToken cancellationToken = default)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null) return Forbid();
        await _context.EnsureUploadedFilesSourceAsync(access, cancellationToken);
        await LoadResourcesAsync(access, archiveVersionId, category, path, resourceId, showDiagnostics, q, filter, page, pageSize, cancellationToken);
        await LoadRepositoryUiAsync(access, category, repositoryContextId, q, filter, sort, page, pageSize, cancellationToken);
        return Page();
    }

    public async Task<IActionResult> OnPostUploadAsync(Guid projectId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanUpload) return Forbid();
        if (Input.Files is null || Input.Files.Count == 0) ModelState.AddModelError("Input.Files", "Select at least one file.");
        if (Input.Files?.Count > ProjectContextLimits.MaxFilesPerUpload) ModelState.AddModelError("Input.Files", $"Upload at most {ProjectContextLimits.MaxFilesPerUpload} files at a time.");
        if (!ModelState.IsValid)
        {
            await LoadResourcesAsync(access, null, null, null, null, false, null, null, 1, 20, cancellationToken);
            return Page();
        }

        string[] tags = SplitTags(Input.Tags);
        foreach (IFormFile file in Input.Files!)
        {
            if (file.Length <= 0) continue;
            if (file.Length > ProjectContextLimits.MaxUploadBytes) throw new InvalidOperationException($"{file.FileName} exceeds the upload size limit.");
            await using var stream = new MemoryStream(checked((int)file.Length));
            await file.CopyToAsync(stream, cancellationToken);
            string? logicalName = Input.Files.Count == 1 ? Input.LogicalName : null;
            await _context.UploadAsync(access, new UploadProjectContextFileCommand(
                projectId, file.FileName, file.ContentType, stream.ToArray(), logicalName, Input.Category, Input.Description, tags,
                Input.MarkCurrent, Input.AgentReadable, Input.IsAuthoritative, access.ActorUserId, DateTime.UtcNow), cancellationToken);
        }

        TempData["Success"] = $"Processed {Input.Files!.Count} Project Context file{(Input.Files.Count == 1 ? string.Empty : "s")}. Identical content is kept as the existing Current version instead of creating a duplicate.";
        return RedirectToPage(new { projectId, category = Input.Category });
    }

    public async Task<IActionResult> OnPostImportFolderAsync(Guid projectId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !CanImportLocalFolder) return Forbid();
        if (string.IsNullOrWhiteSpace(FolderInput.FolderPath)) ModelState.AddModelError("FolderInput.FolderPath", "Enter a folder path on this Dynomax host.");
        if (!ModelState.IsValid)
        {
            await LoadResourcesAsync(access, null, null, null, null, false, null, null, 1, 20, cancellationToken);
            return Page();
        }

        try
        {
            ImportProjectContextFolderResult result = await _context.ImportLocalFolderAsync(access, new ImportProjectContextFolderCommand(
                projectId, FolderInput.FolderPath!, FolderInput.LogicalName, FolderInput.Category, FolderInput.Description, SplitTags(FolderInput.Tags),
                FolderInput.MarkCurrent, FolderInput.AgentReadable, FolderInput.IsAuthoritative, FolderInput.ExcludeGeneratedDirectories,
                access.ActorUserId, DateTime.UtcNow), cancellationToken);
            TempData["Success"] = $"Reconciled local folder with {result.FileCount:N0} file(s), {result.SourceBytes / 1024d / 1024d:N1} MiB source bytes. Unchanged files were left alone, changed files updated their existing logical path, and missing files were retired.";
            return RedirectToPage(new { projectId, category = FolderInput.Category });
        }
        catch (Exception exception) when (exception is ArgumentException or InvalidOperationException or DirectoryNotFoundException or UnauthorizedAccessException or IOException)
        {
            ModelState.AddModelError("FolderInput.FolderPath", exception.Message);
            await LoadResourcesAsync(access, null, null, null, null, false, null, null, 1, 20, cancellationToken);
            return Page();
        }
    }

    public async Task<IActionResult> OnPostCurrentAsync(Guid projectId, Guid resourceId, Guid resourceVersionId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanManage) return Forbid();
        await _context.SetCurrentAsync(access, resourceId, resourceVersionId, cancellationToken);
        TempData["Success"] = "Current Project Context version updated.";
        return RedirectToPage(new { projectId, resourceId });
    }

    public async Task<IActionResult> OnPostRetireAsync(Guid projectId, Guid resourceId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null || !access.CanManage) return Forbid();
        await _context.RetireAsync(access, resourceId, cancellationToken);
        TempData["Success"] = "Project Context resource retired. Immutable versions were preserved.";
        return RedirectToPage(new { projectId });
    }

    public async Task<IActionResult> OnGetDownloadAsync(Guid projectId, Guid resourceVersionId, CancellationToken cancellationToken)
    {
        ProjectContextRequestAccess? access = await LoadAccessAsync(projectId, cancellationToken);
        if (access is null) return Forbid();
        ProjectContextBinaryResult file = await _context.GetFileAsync(access, resourceVersionId, cancellationToken);
        return File(file.Content, file.ContentType, file.FileName);
    }

    private async Task<ProjectContextRequestAccess?> LoadAccessAsync(Guid projectId, CancellationToken cancellationToken)
    {
        if (!User.TryGetUserId(out Guid userId)) return null;
        bool administrator = User.IsSystemAdministrator();
        ProjectAccessContext? projectAccess = await _projectAccess.GetAsync(projectId, userId, administrator, cancellationToken);
        ProjectDetails? project = await _projects.GetAccessibleAsync(projectId, userId, administrator, cancellationToken);
        if (projectAccess?.CanView != true || project is null) return null;

        Project = project;
        bool canRead = (await _authorization.AuthorizeAsync(User, SystemPermissions.ProjectContextRead)).Succeeded;
        bool canUpload = projectAccess.CanMaintain && (await _authorization.AuthorizeAsync(User, SystemPermissions.ProjectContextUpload)).Succeeded;
        bool canManage = projectAccess.CanMaintain && (await _authorization.AuthorizeAsync(User, SystemPermissions.ProjectContextManage)).Succeeded;
        bool canDelete = projectAccess.CanMaintain && (await _authorization.AuthorizeAsync(User, SystemPermissions.ProjectContextDelete)).Succeeded;
        CanUpload = canUpload;
        CanManage = canManage;
        CanImportLocalFolder = _environment.IsDevelopment() && canUpload && canManage;
        var access = new ProjectContextRequestAccess(projectId, userId, canRead, canUpload, canManage, canDelete, false);
        Capabilities = _context.GetCapabilities(access);
        return access;
    }

    private async Task LoadResourcesAsync(
        ProjectContextRequestAccess access,
        Guid? archiveVersionId,
        string? category,
        string? path,
        Guid? resourceId,
        bool showDiagnostics,
        string? search,
        string? filter,
        int page,
        int pageSize,
        CancellationToken cancellationToken)
    {
        var resources = new List<ProjectContextResourceSummary>();
        int skip = 0;
        while (true)
        {
            ProjectContextResourcePage resourcePage = await _context.ListResourcesAsync(access,
                new ProjectContextResourceQuery(access.ProjectId, null, ProjectContextSourceTypes.UploadedFiles, null, null, null, false, true, showDiagnostics, skip, ProjectContextLimits.MaxResourceListTake), cancellationToken);
            resources.AddRange(resourcePage.Items);
            if (resourcePage.Items.Count == 0 || resources.Count >= resourcePage.Total) break;
            skip += resourcePage.Items.Count;
        }

        ShowDiagnostics = showDiagnostics;
        if (!showDiagnostics)
            resources = resources.Where(resource => resource.IsActive && !IsTemporaryResource(resource)).ToList();

        Resources = resources
            .OrderBy(resource => resource.Category ?? "Other", StringComparer.OrdinalIgnoreCase)
            .ThenBy(CurrentLogicalPath, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        Categories = resources
            .GroupBy(resource => string.IsNullOrWhiteSpace(resource.Category) ? "Other" : resource.Category!, StringComparer.OrdinalIgnoreCase)
            .Select(group => new ProjectContextCategorySummary(
                group.Key,
                group.Count(),
                group.Count(resource => resource.IsAuthoritative),
                group.Max(resource => resource.UpdatedAtUtc),
                group.Sum(resource => resource.SizeBytes ?? 0L)))
            .OrderBy(summary => CollectionSortOrder(summary.Name))
            .ThenBy(summary => summary.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        CollectionNavigation = BuildCollectionNavigation(Categories);
        CurrentStorageBytes = resources.Sum(resource => resource.SizeBytes ?? 0L);
        LastImportUtc = resources.Count == 0 ? null : resources.Max(resource => resource.UpdatedAtUtc);
        RecentActivity = BuildRecentActivity(Categories);
        StorageBreakdown = BuildStorageBreakdown(Categories, CurrentStorageBytes);

        BrowseCategory = string.IsNullOrWhiteSpace(category)
            ? Categories.FirstOrDefault(summary => string.Equals(summary.Name, "Source Code", StringComparison.OrdinalIgnoreCase))?.Name
              ?? Categories.FirstOrDefault()?.Name
            : category.Trim();
        BrowsePath = NormalizeBrowsePath(path);
        SearchQuery = search?.Trim() ?? string.Empty;
        Filter = string.IsNullOrWhiteSpace(filter) ? "All" : filter.Trim();
        PageSize = pageSize is 10 or 20 or 50 or 100 ? pageSize : 20;

        IReadOnlyList<ProjectContextBrowseEntry> allBrowseEntries = BrowseCategory is null
            ? []
            : BuildBrowseEntries(resources, BrowseCategory, BrowsePath);
        IEnumerable<ProjectContextBrowseEntry> filtered = allBrowseEntries;
        if (!string.IsNullOrWhiteSpace(SearchQuery))
            filtered = filtered.Where(entry => entry.Name.Contains(SearchQuery, StringComparison.OrdinalIgnoreCase) || entry.Path.Contains(SearchQuery, StringComparison.OrdinalIgnoreCase));
        if (string.Equals(Filter, "Folders", StringComparison.OrdinalIgnoreCase)) filtered = filtered.Where(entry => entry.IsFolder);
        if (string.Equals(Filter, "Files", StringComparison.OrdinalIgnoreCase)) filtered = filtered.Where(entry => !entry.IsFolder);
        if (string.Equals(Filter, "Authoritative", StringComparison.OrdinalIgnoreCase)) filtered = filtered.Where(entry => entry.Resource?.IsAuthoritative == true);
        if (string.Equals(Filter, "Backups", StringComparison.OrdinalIgnoreCase)) filtered = filtered.Where(entry => entry.Resource is not null);

        ProjectContextBrowseEntry[] materialized = filtered.ToArray();
        BrowseTotal = materialized.Length;
        PageNumber = Math.Clamp(page, 1, Math.Max(1, (int)Math.Ceiling(BrowseTotal / (double)PageSize)));
        BrowseEntries = materialized.Skip((PageNumber - 1) * PageSize).Take(PageSize).ToArray();

        Guid? selectedResourceId = resourceId;

        if (selectedResourceId is Guid selected && resources.Any(resource => resource.ResourceId == selected))
        {
            SelectedResource = await _context.GetResourceDetailsAsync(access, selected, cancellationToken);
            if (SelectedResource?.Resource.CurrentVersionId is Guid currentVersionId && IsTextPreviewCandidate(SelectedResource.Resource))
            {
                try
                {
                    ProjectContextTextResult preview = await _context.GetTextAsync(access, currentVersionId, 0, 24_000, null, null, cancellationToken);
                    SelectedPreviewText = preview.Content;
                }
                catch (InvalidOperationException)
                {
                    SelectedPreviewText = null;
                }
            }
        }

        ArchiveVersionId = archiveVersionId;
        if (archiveVersionId is Guid versionId)
        {
            ProjectContextVersionSummary metadata = await _context.GetVersionMetadataAsync(access, versionId, cancellationToken);
            if (string.Equals(metadata.ArchiveType, "zip", StringComparison.Ordinal))
                ArchiveEntries = await _context.ListArchiveEntriesAsync(access, versionId, null, null, null, 0, 300, cancellationToken);
        }
    }

    private static IReadOnlyList<ProjectContextBrowseEntry> BuildBrowseEntries(IReadOnlyList<ProjectContextResourceSummary> resources, string category, string browsePath)
    {
        var folders = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        var files = new List<ProjectContextBrowseEntry>();
        string prefix = string.IsNullOrWhiteSpace(browsePath) ? string.Empty : browsePath + "/";

        foreach (ProjectContextResourceSummary resource in resources.Where(resource =>
                     string.Equals(string.IsNullOrWhiteSpace(resource.Category) ? "Other" : resource.Category, category, StringComparison.OrdinalIgnoreCase)))
        {
            if (resource.CurrentVersionId is null) continue;
            string logicalPath = NormalizeBrowsePath(CurrentLogicalPath(resource));
            string remainder;
            if (prefix.Length == 0)
            {
                remainder = logicalPath;
            }
            else
            {
                if (!logicalPath.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
                remainder = logicalPath[prefix.Length..];
            }

            if (remainder.Length == 0) continue;
            int separator = remainder.IndexOf('/');
            if (separator >= 0)
            {
                string segment = remainder[..separator];
                string folderPath = prefix.Length == 0 ? segment : browsePath + "/" + segment;
                folders[folderPath] = folders.TryGetValue(folderPath, out int count) ? count + 1 : 1;
            }
            else
            {
                files.Add(new ProjectContextBrowseEntry(remainder, logicalPath, false, 1, resource));
            }
        }

        return folders.Select(pair => new ProjectContextBrowseEntry(pair.Key.Split('/').Last(), pair.Key, true, pair.Value, null))
            .Concat(files)
            .OrderByDescending(entry => entry.IsFolder)
            .ThenBy(entry => entry.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static IReadOnlyList<ProjectContextCollectionNavItem> BuildCollectionNavigation(IReadOnlyList<ProjectContextCategorySummary> categories)
    {
        var names = new List<string>(DefaultCollections);
        foreach (string category in categories.Select(item => item.Name))
            if (!names.Contains(category, StringComparer.OrdinalIgnoreCase)) names.Add(category);

        return names.Select(name =>
        {
            ProjectContextCategorySummary? summary = categories.FirstOrDefault(item => string.Equals(item.Name, name, StringComparison.OrdinalIgnoreCase));
            return new ProjectContextCollectionNavItem(name, summary?.ResourceCount ?? 0, summary?.StorageBytes ?? 0L);
        }).ToArray();
    }

    private static IReadOnlyList<ProjectContextActivityRow> BuildRecentActivity(IReadOnlyList<ProjectContextCategorySummary> categories) =>
        categories.OrderByDescending(category => category.UpdatedAtUtc)
            .Take(3)
            .Select(category => new ProjectContextActivityRow(
                category.UpdatedAtUtc,
                category.Name,
                category.ResourceCount,
                category.AuthoritativeCount,
                Math.Max(0, category.ResourceCount - category.AuthoritativeCount)))
            .ToArray();

    private static IReadOnlyList<ProjectContextStorageSlice> BuildStorageBreakdown(IReadOnlyList<ProjectContextCategorySummary> categories, long totalBytes)
    {
        if (totalBytes <= 0) return [];
        return categories.OrderByDescending(category => category.StorageBytes)
            .Take(5)
            .Select(category => new ProjectContextStorageSlice(category.Name, category.StorageBytes, category.StorageBytes * 100d / totalBytes))
            .ToArray();
    }

    private static int CollectionSortOrder(string name)
    {
        int index = Array.FindIndex(DefaultCollections, item => string.Equals(item, name, StringComparison.OrdinalIgnoreCase));
        return index < 0 ? DefaultCollections.Length : index;
    }

    private static bool IsTextPreviewCandidate(ProjectContextResourceSummary resource)
    {
        string fileName = resource.FileName ?? resource.DisplayName;
        string extension = Path.GetExtension(fileName);
        return resource.ContentType?.StartsWith("text/", StringComparison.OrdinalIgnoreCase) == true
            || extension.Equals(".cs", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".cshtml", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".json", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".md", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".txt", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".xml", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".yml", StringComparison.OrdinalIgnoreCase)
            || extension.Equals(".yaml", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsTemporaryResource(ProjectContextResourceSummary resource)
    {
        if (resource.LogicalKey.StartsWith("agent-repair-", StringComparison.OrdinalIgnoreCase)) return true;
        return resource.Tags.Any(tag => string.Equals(tag, "temp", StringComparison.OrdinalIgnoreCase)
                                        || string.Equals(tag, "temporary", StringComparison.OrdinalIgnoreCase)
                                        || string.Equals(tag, "agent-repair", StringComparison.OrdinalIgnoreCase)
                                        || string.Equals(tag, "test-fixture", StringComparison.OrdinalIgnoreCase));
    }

    private static string CurrentLogicalPath(ProjectContextResourceSummary resource) => resource.LogicalPath ?? resource.LogicalKey;

    private static string NormalizeBrowsePath(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return string.Empty;
        return string.Join('/', value.Trim().Replace('\\', '/').Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string[] SplitTags(string? value) => string.IsNullOrWhiteSpace(value)
        ? []
        : value.Split([',', ';', '\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    public sealed record ProjectContextCategorySummary(string Name, int ResourceCount, int AuthoritativeCount, DateTime UpdatedAtUtc, long StorageBytes);
    public sealed record ProjectContextCollectionNavItem(string Name, int ResourceCount, long StorageBytes);
    public sealed record ProjectContextBrowseEntry(string Name, string Path, bool IsFolder, int DescendantCount, ProjectContextResourceSummary? Resource);
    public sealed record ProjectContextActivityRow(DateTime UpdatedAtUtc, string Collection, int Files, int Authoritative, int Other);
    public sealed record ProjectContextStorageSlice(string Name, long Bytes, double Percent);

    public sealed class UploadInput
    {
        [Required] public List<IFormFile> Files { get; set; } = [];
        [StringLength(300)] public string? LogicalName { get; set; }
        [StringLength(100)] public string? Category { get; set; }
        [StringLength(2000)] public string? Description { get; set; }
        [StringLength(1000)] public string? Tags { get; set; }
        public bool MarkCurrent { get; set; } = true;
        public bool AgentReadable { get; set; } = true;
        public bool IsAuthoritative { get; set; }
    }

    public sealed class FolderImportInput
    {
        [StringLength(2000)] public string? FolderPath { get; set; }
        [StringLength(300)] public string? LogicalName { get; set; }
        [StringLength(100)] public string? Category { get; set; } = "Source Code";
        [StringLength(2000)] public string? Description { get; set; }
        [StringLength(1000)] public string? Tags { get; set; }
        public bool MarkCurrent { get; set; } = true;
        public bool AgentReadable { get; set; } = true;
        public bool IsAuthoritative { get; set; } = true;
        public bool ExcludeGeneratedDirectories { get; set; } = true;
    }
}
