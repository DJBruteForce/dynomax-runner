using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Dynomax.Application.ProjectContext.Repositories;

public sealed record RepositoryCredentialReferenceOption(
    Guid SecretReferenceId,
    Guid ProjectEnvironmentId,
    string EnvironmentKey,
    string Key,
    string DisplayName,
    string Provider,
    bool HasManagedValue,
    DateTime? ValueUpdatedAtUtc,
    string? AgentDescription);

public interface IRepositoryCredentialReferenceService
{
    Task<IReadOnlyList<RepositoryCredentialReferenceOption>> ListAsync(
        Guid projectId,
        Guid projectEnvironmentId,
        CancellationToken cancellationToken = default);
}