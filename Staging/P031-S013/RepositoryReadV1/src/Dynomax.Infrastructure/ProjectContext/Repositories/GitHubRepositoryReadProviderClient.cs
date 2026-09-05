using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Dynomax.Application.ProjectContext.Repositories;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class GitHubRepositoryReadProviderClient : IRepositoryReadProviderClient
{
    private const string GitHubApiVersion = "2026-03-10";
    private readonly HttpClient _httpClient;
    private readonly IRepositoryCredentialResolver _credentialResolver;

    public GitHubRepositoryReadProviderClient(HttpClient httpClient, IRepositoryCredentialResolver credentialResolver)
    {
        _httpClient = httpClient;
        _credentialResolver = credentialResolver;
        ValidateBaseAddress(httpClient.BaseAddress);
    }

    public async Task<RepositoryProviderCommitTree> GetCommitTreeAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string commitSha, CancellationToken cancellationToken = default)
    {
        string exactCommit = ValidateShaValue(commitSha);
        using RepositoryCredentialLease credential = await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId, projectEnvironmentId, secretReferenceId, cancellationToken);
        using GitHubJsonResult result = await SendJsonAsync($"repos/{Escape(owner)}/{Escape(name)}/git/commits/{Escape(exactCommit)}", credential, "commit", cancellationToken);
        JsonElement root = result.Document.RootElement;
        string returnedCommit = ValidateShaValue(RequiredString(root, "sha"));
        if (!string.Equals(returnedCommit, exactCommit, StringComparison.OrdinalIgnoreCase))
            throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub resolved a different commit than the exact commit requested.");
        string treeSha = ValidateShaValue(RequiredString(RequiredObject(root, "tree"), "sha"));
        return new RepositoryProviderCommitTree(returnedCommit, treeSha);
    }

    public async Task<RepositoryProviderTree> GetTreeAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string treeSha, CancellationToken cancellationToken = default)
    {
        string exactTree = ValidateShaValue(treeSha);
        using RepositoryCredentialLease credential = await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId, projectEnvironmentId, secretReferenceId, cancellationToken);
        using GitHubJsonResult result = await SendJsonAsync($"repos/{Escape(owner)}/{Escape(name)}/git/trees/{Escape(exactTree)}", credential, "tree", cancellationToken);
        JsonElement root = result.Document.RootElement;
        string returnedTree = ValidateShaValue(RequiredString(root, "sha"));
        if (!string.Equals(returnedTree, exactTree, StringComparison.OrdinalIgnoreCase))
            throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub resolved a different tree than the exact tree requested.");
        bool truncated = OptionalBoolean(root, "truncated") ?? false;
        if (!root.TryGetProperty("tree", out JsonElement tree) || tree.ValueKind != JsonValueKind.Array)
            throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned an invalid tree response.");
        var entries = new List<RepositoryProviderTreeEntry>();
        foreach (JsonElement item in tree.EnumerateArray())
        {
            string path = RequiredString(item, "path");
            string mode = RequiredString(item, "mode");
            string type = RequiredString(item, "type");
            string sha = ValidateShaValue(RequiredString(item, "sha"));
            long? size = OptionalInt64(item, "size");
            entries.Add(new RepositoryProviderTreeEntry(path, mode, type, sha, size));
        }
        return new RepositoryProviderTree(returnedTree, truncated, entries);
    }

    public async Task<RepositoryProviderBlob> GetBlobAsync(Guid projectId, Guid projectEnvironmentId, Guid secretReferenceId, string owner, string name, string blobSha, int maxBytes, CancellationToken cancellationToken = default)
    {
        if (maxBytes < 1 || maxBytes > RepositoryReadLimits.MaxBinaryBlobBytes)
            throw new ArgumentOutOfRangeException(nameof(maxBytes));
        string exactBlob = ValidateShaValue(blobSha);
        using RepositoryCredentialLease credential = await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId, projectEnvironmentId, secretReferenceId, cancellationToken);
        using GitHubJsonResult result = await SendJsonAsync($"repos/{Escape(owner)}/{Escape(name)}/git/blobs/{Escape(exactBlob)}", credential, "blob", cancellationToken);
        JsonElement root = result.Document.RootElement;
        string returnedBlob = ValidateShaValue(RequiredString(root, "sha"));
        if (!string.Equals(returnedBlob, exactBlob, StringComparison.OrdinalIgnoreCase))
            throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub resolved a different blob than the exact blob requested.");
        long size = RequiredInt64(root, "size");
        if (size > maxBytes)
            throw new RepositoryReadException(RepositoryReadErrorCodes.TooLarge, $"Repository blob is {size} bytes and exceeds the {maxBytes}-byte operation limit.");
        string encoding = RequiredString(root, "encoding");
        if (!string.Equals(encoding, "base64", StringComparison.OrdinalIgnoreCase))
            throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned an unsupported blob encoding.");
        string content = RequiredString(root, "content");
        byte[] bytes;
        try { bytes = Convert.FromBase64String(content); }
        catch (FormatException) { throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned invalid blob content."); }
        if (bytes.LongLength != size)
            throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub blob size did not match the returned content.");
        return new RepositoryProviderBlob(returnedBlob, size, bytes);
    }

    private async Task<GitHubJsonResult> SendJsonAsync(string relativePath, RepositoryCredentialLease credential, string resourceKind, CancellationToken cancellationToken)
    {
        using HttpRequestMessage request = CreateRequest(relativePath, credential);
        HttpResponseMessage response;
        try { response = await _httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancellationToken); }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested) { throw Failure(RepositoryProviderErrorCodes.NetworkError, "GitHub did not respond within the configured timeout."); }
        catch (HttpRequestException) { throw Failure(RepositoryProviderErrorCodes.NetworkError, "GitHub could not be reached."); }
        using (response)
        {
            if (!response.IsSuccessStatusCode) throw MapFailure(response, resourceKind);
            try
            {
                await using Stream stream = await response.Content.ReadAsStreamAsync(cancellationToken);
                JsonDocument document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
                return new GitHubJsonResult(document);
            }
            catch (JsonException) { throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned an invalid JSON response.", (int)response.StatusCode); }
        }
    }

    private static HttpRequestMessage CreateRequest(string relativePath, RepositoryCredentialLease credential)
    {
        if (string.IsNullOrWhiteSpace(relativePath) || relativePath.Contains("://", StringComparison.Ordinal) || relativePath.Contains('\\') || relativePath.Contains('\r') || relativePath.Contains('\n'))
            throw Failure(RepositoryProviderErrorCodes.InvalidRepositoryIdentity, "GitHub request path is invalid.");
        var request = new HttpRequestMessage(HttpMethod.Get, new Uri(relativePath, UriKind.Relative));
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", credential.Value);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
        request.Headers.TryAddWithoutValidation("X-GitHub-Api-Version", GitHubApiVersion);
        request.Headers.UserAgent.ParseAdd("Dynomax/1.19.0");
        return request;
    }

    private static RepositoryProviderException MapFailure(HttpResponseMessage response, string resourceKind)
    {
        int status = (int)response.StatusCode;
        if (response.StatusCode == HttpStatusCode.Unauthorized) return Failure(RepositoryProviderErrorCodes.AuthenticationFailed, "GitHub authentication failed.", status);
        if (response.StatusCode == HttpStatusCode.Forbidden && response.Headers.Contains("X-GitHub-SSO")) return Failure(RepositoryProviderErrorCodes.SsoAuthorizationRequired, "GitHub organization authorization is required for this credential.", status);
        if (status == 429 || (status == 403 && HeaderInt64(response, "X-RateLimit-Remaining") == 0)) return Failure(RepositoryProviderErrorCodes.RateLimited, "GitHub rate limit reached.", status);
        if (response.StatusCode == HttpStatusCode.Forbidden) return Failure(RepositoryProviderErrorCodes.PermissionDenied, "GitHub denied the requested repository read.", status);
        if (response.StatusCode == HttpStatusCode.NotFound) return Failure(RepositoryProviderErrorCodes.RepositoryNotFound, $"GitHub {resourceKind} was not found or is not accessible.", status);
        if (status >= 500) return Failure(RepositoryProviderErrorCodes.ProviderUnavailable, "GitHub is temporarily unavailable.", status);
        return Failure(RepositoryProviderErrorCodes.ProviderError, "GitHub rejected the repository read.", status);
    }

    private static string ValidateShaValue(string value)
    {
        string sha = value?.Trim().ToLowerInvariant() ?? string.Empty;
        if (sha.Length is not (40 or 64) || sha.Any(c => !Uri.IsHexDigit(c)))
            throw new RepositoryReadException(RepositoryReadErrorCodes.InvalidCommit, "An exact 40- or 64-character hexadecimal Git object SHA is required.");
        return sha;
    }

    private static void ValidateBaseAddress(Uri? baseAddress)
    {
        if (baseAddress is null || !baseAddress.IsAbsoluteUri || !string.Equals(baseAddress.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) || !string.Equals(baseAddress.Host, "api.github.com", StringComparison.OrdinalIgnoreCase) || !string.IsNullOrEmpty(baseAddress.UserInfo) || (!baseAddress.IsDefaultPort && baseAddress.Port != 443))
            throw new InvalidOperationException("GitHub provider base address must be canonical https://api.github.com/.");
    }

    private static string Escape(string value) => Uri.EscapeDataString(value);
    private static JsonElement RequiredObject(JsonElement element, string property) => element.TryGetProperty(property, out JsonElement value) && value.ValueKind == JsonValueKind.Object ? value : throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned an invalid response shape.");
    private static string RequiredString(JsonElement element, string property) => element.TryGetProperty(property, out JsonElement value) && value.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(value.GetString()) ? value.GetString()! : throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned an incomplete response.");
    private static bool? OptionalBoolean(JsonElement element, string property) => element.TryGetProperty(property, out JsonElement value) ? value.ValueKind == JsonValueKind.True ? true : value.ValueKind == JsonValueKind.False ? false : null : null;
    private static long? OptionalInt64(JsonElement element, string property) => element.TryGetProperty(property, out JsonElement value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out long result) ? result : null;
    private static long RequiredInt64(JsonElement element, string property) => OptionalInt64(element, property) ?? throw Failure(RepositoryProviderErrorCodes.InvalidResponse, "GitHub returned an invalid size value.");
    private static long? HeaderInt64(HttpResponseMessage response, string name) => response.Headers.TryGetValues(name, out IEnumerable<string>? values) && long.TryParse(values.FirstOrDefault(), out long value) ? value : null;
    private static RepositoryProviderException Failure(string code, string message, int? status = null) => new(code, message, status);

    private sealed class GitHubJsonResult : IDisposable
    {
        public GitHubJsonResult(JsonDocument document) => Document = document;
        public JsonDocument Document { get; }
        public void Dispose() => Document.Dispose();
    }
}