using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Application.Security;
using Dynomax.Portal.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Dynomax.Portal.ProjectContext;

[ApiController]
[Route("api/projects/{projectId:guid}/context/repository-worksets")]
[Authorize]
public sealed class RepositoryWorkspaceController : ControllerBase
{
    private readonly IRepositoryWorkspaceService _workspaces;
    private readonly IProjectAccessService _access;
    public RepositoryWorkspaceController(IRepositoryWorkspaceService workspaces, IProjectAccessService access) { _workspaces = workspaces; _access = access; }

    [HttpGet]
    public async Task<IActionResult> List(Guid projectId, [FromQuery] bool includeClosed, CancellationToken cancellationToken) => await ExecuteReadAsync(projectId, access => _workspaces.ListAsync(access, includeClosed, cancellationToken), cancellationToken);
    [HttpGet("{workSetId:guid}")]
    public async Task<IActionResult> Get(Guid projectId, Guid workSetId, CancellationToken cancellationToken) => await ExecuteReadAsync(projectId, access => _workspaces.GetAsync(access, workSetId, cancellationToken), cancellationToken);
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(Guid projectId, [FromBody] CreateRepositoryWorkSetRequest request, CancellationToken cancellationToken) => await ExecuteManageAsync(projectId, access => _workspaces.CreateAsync(access, new CreateRepositoryWorkSetCommand(request.Title, request.Goal, request.LinkedProjectIssueId, request.LinkedProductChangeId, request.LinkedTestingStepId), cancellationToken), cancellationToken);
    [HttpPost("{workSetId:guid}/repositories/{repositoryContextId:guid}")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddRepository(Guid projectId, Guid workSetId, Guid repositoryContextId, [FromBody] AddRepositoryWorkspaceRequest request, CancellationToken cancellationToken) => await ExecuteManageAsync(projectId, access => _workspaces.AddRepositoryAsync(access, workSetId, repositoryContextId, new AddRepositoryWorkspaceCommand(request.ProjectEnvironmentId, request.BaseBranch, request.ExpectedBaseCommitSha, request.RemoteTargetBranch), cancellationToken), cancellationToken);
    [HttpPost("{workSetId:guid}/repositories/{repositoryContextId:guid}/rebuild")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Rebuild(Guid projectId, Guid workSetId, Guid repositoryContextId, [FromBody] RebuildRepositoryWorkspaceRequest request, CancellationToken cancellationToken) => await ExecuteManageAsync(projectId, access => _workspaces.RebuildAsync(access, workSetId, repositoryContextId, new RebuildRepositoryWorkspaceCommand(request.ProjectEnvironmentId, request.ExpectedBaseCommitSha), cancellationToken), cancellationToken);
    [HttpPost("{workSetId:guid}/close")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Close(Guid projectId, Guid workSetId, [FromBody] CloseRepositoryWorkSetRequest request, CancellationToken cancellationToken) => await ExecuteManageAsync(projectId, access => _workspaces.CloseAsync(access, workSetId, new CloseRepositoryWorkSetCommand(request.ExpectedConcurrencyToken), cancellationToken), cancellationToken);

    private async Task<IActionResult> ExecuteReadAsync<T>(Guid projectId, Func<ProjectContextRequestAccess, Task<T>> action, CancellationToken cancellationToken) { ProjectContextRequestAccess? access = await BuildAccessAsync(projectId, false, cancellationToken); if (access is null) return Forbid(); return await ExecuteAsync(action, access); }
    private async Task<IActionResult> ExecuteManageAsync<T>(Guid projectId, Func<ProjectContextRequestAccess, Task<T>> action, CancellationToken cancellationToken) { ProjectContextRequestAccess? access = await BuildAccessAsync(projectId, true, cancellationToken); if (access is null) return Forbid(); return await ExecuteAsync(action, access); }
    private async Task<ProjectContextRequestAccess?> BuildAccessAsync(Guid projectId, bool requireManage, CancellationToken cancellationToken) { if (!User.TryGetUserId(out Guid userId)) return null; var projectAccess = await _access.GetAsync(projectId, userId, User.IsSystemAdministrator(), cancellationToken); if (projectAccess?.CanView != true || (requireManage && projectAccess.CanMaintain != true)) return null; return new ProjectContextRequestAccess(projectId, userId, true, projectAccess.CanMaintain, projectAccess.CanMaintain, projectAccess.CanMaintain, false, null); }
    private async Task<IActionResult> ExecuteAsync<T>(Func<ProjectContextRequestAccess, Task<T>> action, ProjectContextRequestAccess access)
    {
        try { Response.Headers.CacheControl = "no-store, private"; return Ok(await action(access)); }
        catch (RepositoryWorkspaceException ex)
        {
            int status = ex.Code switch { RepositoryWorkspaceErrorCodes.NotFound => 404, RepositoryWorkspaceErrorCodes.PolicyDenied => 403, RepositoryWorkspaceErrorCodes.Conflict or RepositoryWorkspaceErrorCodes.StaleBase => 409, RepositoryWorkspaceErrorCodes.BaseRefNotFound => 422, RepositoryWorkspaceErrorCodes.MaterializationFailed => 424, _ => 400 };
            return StatusCode(status, new { code = ex.Code, message = ex.Message });
        }
    }
}

public sealed record CreateRepositoryWorkSetRequest(string Title, string Goal, Guid? LinkedProjectIssueId, Guid? LinkedProductChangeId, Guid? LinkedTestingStepId);
public sealed record AddRepositoryWorkspaceRequest(Guid ProjectEnvironmentId, string BaseBranch, string? ExpectedBaseCommitSha, string? RemoteTargetBranch);
public sealed record RebuildRepositoryWorkspaceRequest(Guid ProjectEnvironmentId, string? ExpectedBaseCommitSha);
public sealed record CloseRepositoryWorkSetRequest(string ExpectedConcurrencyToken);