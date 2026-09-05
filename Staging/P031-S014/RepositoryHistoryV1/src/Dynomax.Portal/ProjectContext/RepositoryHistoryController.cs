using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Application.Security;
using Dynomax.Portal.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Dynomax.Portal.ProjectContext;

[ApiController]
[Route("api/projects/{projectId:guid}/context/repository-history")]
[Authorize]
public sealed class RepositoryHistoryController : ControllerBase
{
    private readonly IRepositoryHistoryService _history; private readonly IProjectAccessService _access;
    public RepositoryHistoryController(IRepositoryHistoryService history,IProjectAccessService access){_history=history;_access=access;}
    [HttpGet("{repositoryContextId:guid}/branches")] public Task<IActionResult> Branches(Guid projectId,Guid repositoryContextId,[FromQuery]Guid projectEnvironmentId,[FromQuery]int page=1,[FromQuery]int pageSize=100,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.ListBranchesAsync(a,projectEnvironmentId,repositoryContextId,page,pageSize,ct),ct);
    [HttpGet("{repositoryContextId:guid}/branches/{*branch}")] public Task<IActionResult> Branch(Guid projectId,Guid repositoryContextId,string branch,[FromQuery]Guid projectEnvironmentId,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.GetBranchAsync(a,projectEnvironmentId,repositoryContextId,branch,ct),ct);
    [HttpGet("{repositoryContextId:guid}/tags")] public Task<IActionResult> Tags(Guid projectId,Guid repositoryContextId,[FromQuery]Guid projectEnvironmentId,[FromQuery]int page=1,[FromQuery]int pageSize=100,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.ListTagsAsync(a,projectEnvironmentId,repositoryContextId,page,pageSize,ct),ct);
    [HttpGet("{repositoryContextId:guid}/resolve-ref")] public Task<IActionResult> ResolveRef(Guid projectId,Guid repositoryContextId,[FromQuery]Guid projectEnvironmentId,[FromQuery]string refType,[FromQuery]string value,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.ResolveRefAsync(a,projectEnvironmentId,repositoryContextId,refType,value,ct),ct);
    [HttpGet("{repositoryContextId:guid}/commits")] public Task<IActionResult> Commits(Guid projectId,Guid repositoryContextId,[FromQuery]Guid projectEnvironmentId,[FromQuery]string? commitSha,[FromQuery]string? path,[FromQuery]int page=1,[FromQuery]int pageSize=100,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.ListCommitsAsync(a,projectEnvironmentId,repositoryContextId,commitSha,path,page,pageSize,ct),ct);
    [HttpGet("{repositoryContextId:guid}/commits/{commitSha}")] public Task<IActionResult> Commit(Guid projectId,Guid repositoryContextId,string commitSha,[FromQuery]Guid projectEnvironmentId,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.GetCommitAsync(a,projectEnvironmentId,repositoryContextId,commitSha,ct),ct);
    [HttpGet("{repositoryContextId:guid}/compare")] public Task<IActionResult> Compare(Guid projectId,Guid repositoryContextId,[FromQuery]Guid projectEnvironmentId,[FromQuery]string? baseSha,[FromQuery]string? headSha,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.CompareAsync(a,projectEnvironmentId,repositoryContextId,baseSha,headSha,ct),ct);
    [HttpGet("{repositoryContextId:guid}/blame")] public Task<IActionResult> Blame(Guid projectId,Guid repositoryContextId,[FromQuery]Guid projectEnvironmentId,[FromQuery]string? commitSha,[FromQuery]string path,CancellationToken ct=default)=>ExecuteAsync(projectId,a=>_history.GetBlameAsync(a,projectEnvironmentId,repositoryContextId,commitSha,path,ct),ct);
    private async Task<IActionResult> ExecuteAsync<T>(Guid projectId,Func<ProjectContextRequestAccess,Task<T>> action,CancellationToken ct){ProjectContextRequestAccess? access=await BuildAccessAsync(projectId,ct);if(access is null)return Forbid();try{Response.Headers.CacheControl="no-store, private";return Ok(await action(access));}catch(RepositoryHistoryException ex){return ex.Code switch{RepositoryHistoryErrorCodes.NotFound=>NotFound(new{code=ex.Code,message=ex.Message}),RepositoryHistoryErrorCodes.PolicyDenied=>StatusCode(403,new{code=ex.Code,message=ex.Message}),RepositoryHistoryErrorCodes.TooLarge=>StatusCode(413,new{code=ex.Code,message=ex.Message}),_=>BadRequest(new{code=ex.Code,message=ex.Message})};}catch(RepositoryProviderException ex){int status=ex.Code switch{RepositoryProviderErrorCodes.RateLimited=>429,RepositoryProviderErrorCodes.ProviderUnavailable or RepositoryProviderErrorCodes.NetworkError=>503,RepositoryProviderErrorCodes.RepositoryNotFound=>404,RepositoryProviderErrorCodes.PermissionDenied=>403,_=>424};return StatusCode(status,new{code=ex.Code,message=ex.Message,retryAtUtc=ex.RetryAtUtc});}}
    private async Task<ProjectContextRequestAccess?> BuildAccessAsync(Guid projectId,CancellationToken ct){if(!User.TryGetUserId(out Guid userId))return null;var p=await _access.GetAsync(projectId,userId,User.IsSystemAdministrator(),ct);if(p?.CanView!=true)return null;return new ProjectContextRequestAccess(projectId,userId,true,p.CanMaintain,p.CanMaintain,p.CanMaintain,false,null);}
}