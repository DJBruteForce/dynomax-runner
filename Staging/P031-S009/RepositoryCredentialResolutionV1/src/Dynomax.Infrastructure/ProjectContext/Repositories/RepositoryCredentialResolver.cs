using System.Security;
using Dynomax.Application.Projects.TestData;
using Dynomax.Domain.Projects.Configuration;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal static class RepositoryCredentialErrorCodes
{
    public const string EnvironmentUnavailable = "REPOSITORY_CREDENTIAL_ENVIRONMENT_UNAVAILABLE";
    public const string ReferenceUnavailable = "REPOSITORY_CREDENTIAL_REFERENCE_UNAVAILABLE";
    public const string ReferenceInactive = "REPOSITORY_CREDENTIAL_REFERENCE_INACTIVE";
    public const string ProviderInvalid = "REPOSITORY_CREDENTIAL_PROVIDER_INVALID";
    public const string ValueUnavailable = "REPOSITORY_CREDENTIAL_VALUE_UNAVAILABLE";
    public const string CredentialTypeMismatch = "REPOSITORY_CREDENTIAL_TYPE_MISMATCH";
}

internal sealed class RepositoryCredentialResolutionException : InvalidOperationException
{
    public RepositoryCredentialResolutionException(string code, string message)
        : base(message)
    {
        Code = code;
    }

    public string Code { get; }
}

internal interface IRepositoryCredentialResolver
{
    Task<RepositoryCredentialLease> ResolveGitHubFineGrainedPatAsync(
        Guid projectId,
        Guid projectEnvironmentId,
        Guid secretReferenceId,
        CancellationToken cancellationToken = default);
}

internal sealed class RepositoryCredentialLease : IDisposable
{
    private string? _value;

    internal RepositoryCredentialLease(
        Guid secretReferenceId,
        string provider,
        DateTime? valueUpdatedAtUtc,
        string value)
    {
        SecretReferenceId = secretReferenceId;
        Provider = provider;
        ValueUpdatedAtUtc = valueUpdatedAtUtc;
        _value = value;
    }

    internal Guid SecretReferenceId { get; }
    internal string Provider { get; }
    internal DateTime? ValueUpdatedAtUtc { get; }
    internal string Value => _value ?? throw new ObjectDisposedException(nameof(RepositoryCredentialLease));

    internal string Redact(string? text)
    {
        if (string.IsNullOrEmpty(text)) return text ?? string.Empty;
        string secret = Value;
        return text.Replace(secret, "[REDACTED]", StringComparison.Ordinal);
    }

    public override string ToString() => $"RepositoryCredentialLease({SecretReferenceId:D}, {Provider})";

    public void Dispose()
    {
        _value = null;
    }
}

internal sealed class RepositoryCredentialResolver : IRepositoryCredentialResolver
{
    private readonly DynomaxDbContext _dbContext;
    private readonly IProjectManagedSecretValueResolver _managedSecretValueResolver;
    private readonly IConfiguration _configuration;

    public RepositoryCredentialResolver(
        DynomaxDbContext dbContext,
        IProjectManagedSecretValueResolver managedSecretValueResolver,
        IConfiguration configuration)
    {
        _dbContext = dbContext;
        _managedSecretValueResolver = managedSecretValueResolver;
        _configuration = configuration;
    }

    public async Task<RepositoryCredentialLease> ResolveGitHubFineGrainedPatAsync(
        Guid projectId,
        Guid projectEnvironmentId,
        Guid secretReferenceId,
        CancellationToken cancellationToken = default)
    {
        if (projectId == Guid.Empty || projectEnvironmentId == Guid.Empty || secretReferenceId == Guid.Empty)
            throw Failure(RepositoryCredentialErrorCodes.ReferenceUnavailable, "Repository credential reference is unavailable.");

        ProjectEnvironment? environment = await _dbContext.ProjectEnvironments
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.Id == projectEnvironmentId && item.ProjectId == projectId && item.IsActive,
                cancellationToken);

        if (environment is null)
            throw Failure(RepositoryCredentialErrorCodes.EnvironmentUnavailable, "Repository credential environment is unavailable.");

        ProjectSecretReference? secretReference = await _dbContext.ProjectSecretReferences
            .AsNoTracking()
            .SingleOrDefaultAsync(
                item => item.Id == secretReferenceId &&
                        item.ProjectId == projectId &&
                        item.ProjectEnvironmentId == projectEnvironmentId,
                cancellationToken);

        if (secretReference is null)
            throw Failure(RepositoryCredentialErrorCodes.ReferenceUnavailable, "Repository credential reference is unavailable.");
        if (!secretReference.IsActive)
            throw Failure(RepositoryCredentialErrorCodes.ReferenceInactive, "Repository credential reference is inactive.");

        string normalizedReference;
        try
        {
            normalizedReference = ProjectSecretReference.NormalizeProviderReference(
                secretReference.Provider,
                secretReference.ProviderReference);
        }
        catch (ArgumentException)
        {
            throw Failure(RepositoryCredentialErrorCodes.ProviderInvalid, "Repository credential provider configuration is invalid.");
        }

        string? value;
        if (string.Equals(secretReference.Provider, SecretReferenceProviders.PortalManaged, StringComparison.Ordinal))
        {
            if (!secretReference.HasStoredValue)
                throw Failure(RepositoryCredentialErrorCodes.ValueUnavailable, "Repository credential value is unavailable.");

            value = await _managedSecretValueResolver.ResolveAsync(
                projectId,
                environment.Key,
                normalizedReference,
                cancellationToken);
        }
        else if (string.Equals(secretReference.Provider, SecretReferenceProviders.EnvironmentVariable, StringComparison.Ordinal))
        {
            value = ResolveEnvironmentVariable(normalizedReference);
        }
        else if (string.Equals(secretReference.Provider, SecretReferenceProviders.AppSettings, StringComparison.Ordinal))
        {
            value = _configuration[normalizedReference];
        }
        else
        {
            throw Failure(RepositoryCredentialErrorCodes.ProviderInvalid, "Repository credential provider configuration is invalid.");
        }

        if (string.IsNullOrWhiteSpace(value))
            throw Failure(RepositoryCredentialErrorCodes.ValueUnavailable, "Repository credential value is unavailable.");
        if (!IsGitHubFineGrainedPat(value))
            throw Failure(RepositoryCredentialErrorCodes.CredentialTypeMismatch, "Repository credential is not an accepted GitHub fine-grained token.");

        return new RepositoryCredentialLease(
            secretReference.Id,
            secretReference.Provider,
            secretReference.ValueUpdatedAtUtc,
            value);
    }

    private static string? ResolveEnvironmentVariable(string reference)
    {
        string? value = Environment.GetEnvironmentVariable(reference);
        if (value is not null || !OperatingSystem.IsWindows())
            return value;

        try
        {
            value = Environment.GetEnvironmentVariable(reference, EnvironmentVariableTarget.User);
            if (value is not null) return value;
        }
        catch (SecurityException)
        {
        }

        try
        {
            return Environment.GetEnvironmentVariable(reference, EnvironmentVariableTarget.Machine);
        }
        catch (SecurityException)
        {
            return null;
        }
    }

    private static bool IsGitHubFineGrainedPat(string value) =>
        value.StartsWith("github_pat_", StringComparison.Ordinal) &&
        value.Length >= 30 &&
        !value.Any(char.IsWhiteSpace);

    private static RepositoryCredentialResolutionException Failure(string code, string message) => new(code, message);
}