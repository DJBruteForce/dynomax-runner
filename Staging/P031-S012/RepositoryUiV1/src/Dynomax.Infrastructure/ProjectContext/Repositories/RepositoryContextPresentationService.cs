using Dynomax.Application.ProjectContext;
using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Domain.ProjectContext;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class RepositoryContextPresentationService : IRepositoryContextPresentationService
{
    private readonly DynomaxDbContext _db;
    private readonly IRepositoryConnectionService _connections;
    private readonly IRepositoryCredentialReferenceService _credentials;

    public RepositoryContextPresentationService(
        DynomaxDbContext db,
        IRepositoryConnectionService connections,
        IRepositoryCredentialReferenceService credentials)
    {
        _db = db;
        _connections = connections;
        _credentials = credentials;
    }

    public async Task<IReadOnlyList<RepositoryContextPresentationRow>> ListAsync(
        ProjectContextRequestAccess access,
        bool includeInactive,
        CancellationToken cancellationToken = default)
    {
        RequireRead(access);
        IReadOnlyList<RepositoryConnectionSummary> connections = await _connections.ListAsync(access, includeInactive, cancellationToken);
        if (connections.Count == 0) return Array.Empty<RepositoryContextPresentationRow>();

        IReadOnlyList<RepositoryCredentialReferenceOption> credentials = await ListCredentialOptionsAsync(access, cancellationToken);
        var credentialById = credentials.ToDictionary(item => item.SecretReferenceId);
        Guid[] repositoryIds = connections.Select(item => item.RepositoryContextId).ToArray();

        Dictionary<Guid, int> workspaceCounts = await _db.RepositoryWorkspaces.AsNoTracking()
            .Where(item => repositoryIds.Contains(item.RepositoryContextId) && item.State != RepositoryWorkspaceStates.Closed)
            .GroupBy(item => item.RepositoryContextId)
            .Select(group => new { RepositoryContextId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.RepositoryContextId, item => item.Count, cancellationToken);

        Dictionary<Guid, int> pullRequestCounts = await _db.RepositoryPullRequestLinks.AsNoTracking()
            .Where(item => repositoryIds.Contains(item.RepositoryContextId)
                           && item.State != "closed" && item.State != "Closed"
                           && item.State != "merged" && item.State != "Merged")
            .GroupBy(item => item.RepositoryContextId)
            .Select(group => new { RepositoryContextId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(item => item.RepositoryContextId, item => item.Count, cancellationToken);

        return connections.Select(connection => new RepositoryContextPresentationRow(
                connection,
                credentialById.GetValueOrDefault(connection.CredentialSecretReferenceId),
                workspaceCounts.GetValueOrDefault(connection.RepositoryContextId),
                pullRequestCounts.GetValueOrDefault(connection.RepositoryContextId)))
            .ToArray();
    }

    public async Task<IReadOnlyList<RepositoryCredentialReferenceOption>> ListCredentialOptionsAsync(
        ProjectContextRequestAccess access,
        CancellationToken cancellationToken = default)
    {
        RequireRead(access);
        Guid[] environmentIds = await _db.ProjectEnvironments.AsNoTracking()
            .Where(environment => environment.ProjectId == access.ProjectId && environment.IsActive)
            .OrderByDescending(environment => environment.IsDefault)
            .ThenBy(environment => environment.Key)
            .Select(environment => environment.Id)
            .ToArrayAsync(cancellationToken);

        var result = new List<RepositoryCredentialReferenceOption>();
        foreach (Guid environmentId in environmentIds)
            result.AddRange(await _credentials.ListAsync(access.ProjectId, environmentId, cancellationToken));

        return result
            .OrderBy(item => item.EnvironmentKey, StringComparer.OrdinalIgnoreCase)
            .ThenBy(item => item.DisplayName, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static void RequireRead(ProjectContextRequestAccess access)
    {
        if (access.ProjectId == Guid.Empty || access.ActorUserId == Guid.Empty || !access.CanRead)
            throw new UnauthorizedAccessException("Project Context read access is required.");
    }
}