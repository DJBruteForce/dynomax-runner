using Dynomax.Application.ProjectContext;

namespace Dynomax.Application.ProjectContext.Repositories;

public sealed record RepositoryContextPresentationRow(
    RepositoryConnectionSummary Connection,
    RepositoryCredentialReferenceOption? Credential,
    int OpenWorkspaceCount,
    int OpenPullRequestCount);

public interface IRepositoryContextPresentationService
{
    Task<IReadOnlyList<RepositoryContextPresentationRow>> ListAsync(
        ProjectContextRequestAccess access,
        bool includeInactive,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RepositoryCredentialReferenceOption>> ListCredentialOptionsAsync(
        ProjectContextRequestAccess access,
        CancellationToken cancellationToken = default);
}