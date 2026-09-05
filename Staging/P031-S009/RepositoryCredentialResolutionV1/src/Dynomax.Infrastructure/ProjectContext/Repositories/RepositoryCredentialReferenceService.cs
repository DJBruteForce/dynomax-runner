using Dynomax.Application.ProjectContext.Repositories;
using Dynomax.Domain.Projects.Configuration;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class RepositoryCredentialReferenceService : IRepositoryCredentialReferenceService
{
    private readonly DynomaxDbContext _dbContext;

    public RepositoryCredentialReferenceService(DynomaxDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task<IReadOnlyList<RepositoryCredentialReferenceOption>> ListAsync(
        Guid projectId,
        Guid projectEnvironmentId,
        CancellationToken cancellationToken = default)
    {
        if (projectId == Guid.Empty) throw new ArgumentException("Project ID is required.", nameof(projectId));
        if (projectEnvironmentId == Guid.Empty) throw new ArgumentException("Environment ID is required.", nameof(projectEnvironmentId));

        ProjectEnvironment? environment = await _dbContext.ProjectEnvironments
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.Id == projectEnvironmentId && item.ProjectId == projectId && item.IsActive,
                cancellationToken);

        if (environment is null)
            return Array.Empty<RepositoryCredentialReferenceOption>();

        return await _dbContext.ProjectSecretReferences
            .AsNoTracking()
            .Where(item =>
                item.ProjectId == projectId &&
                item.ProjectEnvironmentId == projectEnvironmentId &&
                item.IsActive &&
                (item.Provider == SecretReferenceProviders.PortalManaged ||
                 item.Provider == SecretReferenceProviders.EnvironmentVariable ||
                 item.Provider == SecretReferenceProviders.AppSettings))
            .OrderBy(item => item.DisplayName)
            .ThenBy(item => item.Key)
            .Select(item => new RepositoryCredentialReferenceOption(
                item.Id,
                item.ProjectEnvironmentId,
                environment.Key,
                item.Key,
                item.DisplayName,
                item.Provider,
                item.ProtectedValue != null && item.ProtectedValue != string.Empty,
                item.ValueUpdatedAtUtc,
                item.AgentDescription))
            .ToArrayAsync(cancellationToken);
    }
}