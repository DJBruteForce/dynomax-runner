using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Application.Security;
using Dynomax.Portal.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
namespace Dynomax.Portal.ProjectContext;

[ApiController]
[Route("api/projects/{projectId:guid}/context/repositories")]
[Authorize]
public sealed class RepositoryConnectionController : ControllerBase
{
 private readonly IRepositoryConnectionService _repositories; private readonly IProjectAccessService _access;
 public RepositoryConnectionController(IRepositoryConnectionService repositories,IProjectAccessService access){_repositories=repositories;_access=access;}
 [HttpGet] public async Task<IActionResult> List(Guid projectId,[FromQuery] bool includeInactive,CancellationToken ct)=>await ExecuteReadAsync(projectId,a=>_repositories.ListAsync(a,includeInactive,ct),ct);
 [HttpGet("{repositoryContextId:guid}")] public async Task<IActionResult> Get(Guid projectId,Guid repositoryContextId,CancellationToken ct)=>await ExecuteReadAsync(projectId,a=>_repositories.GetAsync(a,repositoryContextId,ct),ct);
 [HttpGet("validate")] public async Task<IActionResult> Validate(Guid projectId,[FromQuery] Guid projectEnvironmentId,[FromQuery] string repositoryUrl,[FromQuery] Guid credentialSecretReferenceId,CancellationToken ct)=>await ExecuteManageAsync(projectId,a=>_repositories.ValidateAsync(a,projectEnvironmentId,repositoryUrl,credentialSecretReferenceId,ct),ct);
 [HttpPost][ValidateAntiForgeryToken] public async Task<IActionResult> Connect(Guid projectId,[FromBody] ConnectRepositoryRequest request,CancellationToken ct)=>await ExecuteManageAsync(projectId,a=>_repositories.ConnectAsync(a,new ConnectRepositoryCommand(request.ProjectEnvironmentId,request.RepositoryUrl,request.CredentialSecretReferenceId,request.Role,request.Purpose,request.Tags??Array.Empty<string>()),ct),ct);
 [HttpPost("{repositoryContextId:guid}/refresh")][ValidateAntiForgeryToken] public async Task<IActionResult> Refresh(Guid projectId,Guid repositoryContextId,[FromBody] RefreshRepositoryRequest request,CancellationToken ct)=>await ExecuteManageAsync(projectId,a=>_repositories.RefreshAsync(a,request.ProjectEnvironmentId,repositoryContextId,ct),ct);
 [HttpPost("refresh-all")][ValidateAntiForgeryToken] public async Task<IActionResult> RefreshAll(Guid projectId,[FromBody] RefreshRepositoryRequest request,CancellationToken ct)=>await ExecuteManageAsync(projectId,a=>_repositories.RefreshAllAsync(a,request.ProjectEnvironmentId,ct),ct);
 [HttpPut("{repositoryContextId:guid}")][ValidateAntiForgeryToken] public async Task<IActionResult> Update(Guid projectId,Guid repositoryContextId,[FromBody] UpdateRepositoryConnectionRequest request,CancellationToken ct)=>await ExecuteManageAsync(projectId,a=>_repositories.UpdateAsync(a,repositoryContextId,new UpdateRepositoryConnectionCommand(request.ProjectEnvironmentId,request.CredentialSecretReferenceId,request.Role,request.Purpose,request.Tags??Array.Empty<string>(),request.Policy,request.ExpectedConcurrencyToken),ct),ct);
 [HttpDelete("{repositoryContextId:guid}")][ValidateAntiForgeryToken] public async Task<IActionResult> Disconnect(Guid projectId,Guid repositoryContextId,[FromQuery] string expectedConcurrencyToken,CancellationToken ct)=>await ExecuteManageAsync(projectId,a=>_repositories.DisconnectAsync(a,repositoryContextId,expectedConcurrencyToken,ct),ct);
 private async Task<IActionResult> ExecuteReadAsync<T>(Guid projectId,Func<ProjectContextRequestAccess,Task<T>> action,CancellationToken ct){var a=await BuildAccessAsync(projectId,false,ct);if(a is null)return Forbid();return await ExecuteAsync(action,a);}
 private async Task<IActionResult> ExecuteManageAsync<T>(Guid projectId,Func<ProjectContextRequestAccess,Task<T>> action,CancellationToken ct){var a=await BuildAccessAsync(projectId,true,ct);if(a is null)return Forbid();return await ExecuteAsync(action,a);}
 private async Task<ProjectContextRequestAccess?> BuildAccessAsync(Guid projectId,bool requireManage,CancellationToken ct){if(!User.TryGetUserId(out Guid userId))return null;var p=await _access.GetAsync(projectId,userId,User.IsSystemAdministrator(),ct);if(p?.CanView!=true||(requireManage&&p.CanMaintain!=true))return null;return new ProjectContextRequestAccess(projectId,userId,true,p.CanMaintain,p.CanMaintain,p.CanMaintain,false,null);}
 private async Task<IActionResult> ExecuteAsync<T>(Func<ProjectContextRequestAccess,Task<T>> action,ProjectContextRequestAccess access){try{Response.Headers.CacheControl="no-store, private";return Ok(await action(access));}catch(RepositoryConnectionException ex){return ex.Code switch{RepositoryConnectionErrorCodes.NotFound=>NotFound(new{code=ex.Code,message=ex.Message}),RepositoryConnectionErrorCodes.Duplicate or RepositoryConnectionErrorCodes.ConcurrencyConflict=>Conflict(new{code=ex.Code,message=ex.Message}),_=>BadRequest(new{code=ex.Code,message=ex.Message})};}catch(RepositoryProviderException ex){int status=ex.Code switch{RepositoryProviderErrorCodes.InvalidRepositoryIdentity=>400,RepositoryProviderErrorCodes.RateLimited=>429,RepositoryProviderErrorCodes.ProviderUnavailable or RepositoryProviderErrorCodes.NetworkError=>503,_=>424};return StatusCode(status,new{code=ex.Code,message=ex.Message,retryAtUtc=ex.RetryAtUtc});}}
}
public sealed record ConnectRepositoryRequest(Guid ProjectEnvironmentId,string RepositoryUrl,Guid CredentialSecretReferenceId,string? Role,string? Purpose,IReadOnlyList<string>? Tags);
public sealed record RefreshRepositoryRequest(Guid ProjectEnvironmentId);
public sealed record UpdateRepositoryConnectionRequest(Guid ProjectEnvironmentId,Guid? CredentialSecretReferenceId,string? Role,string? Purpose,IReadOnlyList<string>? Tags,RepositoryPolicyUpdate Policy,string ExpectedConcurrencyToken);