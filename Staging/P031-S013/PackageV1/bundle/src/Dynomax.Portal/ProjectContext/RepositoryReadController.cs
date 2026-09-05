using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Application.Security;
using Dynomax.Portal.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Dynomax.Portal.ProjectContext;

[ApiController]
[Route("api/projects/{projectId:guid}/context/repository-read")]
[Authorize]
public sealed class RepositoryReadController : ControllerBase
{
    private readonly IRepositoryReadService _reads;
    private readonly IProjectAccessService _access;

    public RepositoryReadController(IRepositoryReadService reads, IProjectAccessService access)
    {
        _reads = reads;
        _access = access;
    }

    [HttpGet("topology")]
    public Task<IActionResult> Topology(Guid projectId, CancellationToken ct) => ExecuteReadAsync(projectId, a => _reads.GetTopologyAsync(a, ct), ct);

    [HttpGet("{repositoryContextId:guid}/tree")]
    public Task<IActionResult> Tree(Guid projectId, Guid repositoryContextId, [FromQuery] Guid projectEnvironmentId, [FromQuery] string? commitSha, [FromQuery] string? prefix, [FromQuery] int? maxDepth, [FromQuery] int skip = 0, [FromQuery] int take = 250, CancellationToken ct = default) => ExecuteReadAsync(projectId, a => _reads.GetTreeAsync(a, projectEnvironmentId, repositoryContextId, commitSha, prefix, maxDepth, skip, take, ct), ct);

    [HttpPost("search")]
    [ValidateAntiForgeryToken]
    public Task<IActionResult> Search(Guid projectId, [FromBody] RepositorySearchRequest request, CancellationToken ct) => ExecuteReadAsync(projectId, a => _reads.SearchAsync(a, request, ct), ct);

    [HttpGet("{repositoryContextId:guid}/files/metadata")]
    public Task<IActionResult> Metadata(Guid projectId, Guid repositoryContextId, [FromQuery] Guid projectEnvironmentId, [FromQuery] string? commitSha, [FromQuery] string path, CancellationToken ct) => ExecuteReadAsync(projectId, a => _reads.GetFileMetadataAsync(a, projectEnvironmentId, repositoryContextId, commitSha, path, ct), ct);

    [HttpGet("{repositoryContextId:guid}/files/text")]
    public Task<IActionResult> Text(Guid projectId, Guid repositoryContextId, [FromQuery] Guid projectEnvironmentId, [FromQuery] string? commitSha, [FromQuery] string path, [FromQuery] long? offset, [FromQuery] int? maxCharacters, [FromQuery] int? lineStart, [FromQuery] int? lineCount, CancellationToken ct) => ExecuteReadAsync(projectId, a => _reads.ReadTextAsync(a, projectEnvironmentId, repositoryContextId, commitSha, path, offset, maxCharacters, lineStart, lineCount, ct), ct);

    [HttpGet("{repositoryContextId:guid}/files/binary-segment")]
    public Task<IActionResult> BinarySegment(Guid projectId, Guid repositoryContextId, [FromQuery] Guid projectEnvironmentId, [FromQuery] string? commitSha, [FromQuery] string path, [FromQuery] long offset = 0, [FromQuery] int maxBytes = 262144, CancellationToken ct = default) => ExecuteReadAsync(projectId, a => _reads.ReadBinarySegmentAsync(a, projectEnvironmentId, repositoryContextId, commitSha, path, offset, maxBytes, ct), ct);

    private async Task<IActionResult> ExecuteReadAsync<T>(Guid projectId, Func<ProjectContextRequestAccess, Task<T>> action, CancellationToken ct)
    {
        ProjectContextRequestAccess? access = await BuildAccessAsync(projectId, ct);
        if (access is null) return Forbid();
        try
        {
            Response.Headers.CacheControl = "no-store, private";
            return Ok(await action(access));
        }
        catch (RepositoryReadException ex)
        {
            return ex.Code switch
            {
                RepositoryReadErrorCodes.NotFound => NotFound(new { code = ex.Code, message = ex.Message }),
                RepositoryReadErrorCodes.PolicyDenied => StatusCode(StatusCodes.Status403Forbidden, new { code = ex.Code, message = ex.Message }),
                RepositoryReadErrorCodes.TooLarge => StatusCode(StatusCodes.Status413PayloadTooLarge, new { code = ex.Code, message = ex.Message }),
                RepositoryReadErrorCodes.BinaryFile or RepositoryReadErrorCodes.TextFileExpected or RepositoryReadErrorCodes.SymlinkDenied or RepositoryReadErrorCodes.UnsupportedObject => Conflict(new { code = ex.Code, message = ex.Message }),
                _ => BadRequest(new { code = ex.Code, message = ex.Message })
            };
        }
        catch (RepositoryProviderException ex)
        {
            int status = ex.Code switch
            {
                RepositoryProviderErrorCodes.InvalidRepositoryIdentity => 400,
                RepositoryProviderErrorCodes.RateLimited => 429,
                RepositoryProviderErrorCodes.ProviderUnavailable or RepositoryProviderErrorCodes.NetworkError => 503,
                _ => 424
            };
            return StatusCode(status, new { code = ex.Code, message = ex.Message, retryAtUtc = ex.RetryAtUtc });
        }
    }

    private async Task<ProjectContextRequestAccess?> BuildAccessAsync(Guid projectId, CancellationToken ct)
    {
        if (!User.TryGetUserId(out Guid userId)) return null;
        var projectAccess = await _access.GetAsync(projectId, userId, User.IsSystemAdministrator(), ct);
        if (projectAccess?.CanView != true) return null;
        return new ProjectContextRequestAccess(projectId, userId, true, projectAccess.CanMaintain, projectAccess.CanMaintain, projectAccess.CanMaintain, false, null);
    }
}