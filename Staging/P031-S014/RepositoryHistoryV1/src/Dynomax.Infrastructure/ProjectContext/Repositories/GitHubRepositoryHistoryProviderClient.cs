using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Dynomax.Application.ProjectContext.Repositories;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class GitHubRepositoryHistoryProviderClient : IRepositoryHistoryProviderClient
{
    private const string GitHubApiVersion = "2026-03-10";
    private readonly HttpClient _httpClient;
    private readonly IRepositoryCredentialResolver _credentialResolver;
    public GitHubRepositoryHistoryProviderClient(HttpClient httpClient, IRepositoryCredentialResolver credentialResolver) { _httpClient = httpClient; _credentialResolver = credentialResolver; ValidateBaseAddress(httpClient.BaseAddress); }

    public async Task<IReadOnlyList<RepositoryProviderBranch>> ListBranchesAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, int page, int pageSize, CancellationToken ct = default)
    {
        using RepositoryCredentialLease credential = await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId, envId, secretId, ct);
        using GitHubJsonResult result = await SendJsonAsync(HttpMethod.Get, $"repos/{E(owner)}/{E(name)}/branches?page={page}&per_page={pageSize}", credential, null, "branches", ct);
        if (result.Document.RootElement.ValueKind != JsonValueKind.Array) throw InvalidResponse();
        return result.Document.RootElement.EnumerateArray().Select(x => new RepositoryProviderBranch(S(x,"name"), Sha(S(O(x,"commit"),"sha")), B(x,"protected") ?? false)).ToArray();
    }

    public async Task<RepositoryProviderBranchDetail> GetBranchAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, string branch, CancellationToken ct = default)
    {
        using RepositoryCredentialLease credential = await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId, envId, secretId, ct);
        using GitHubJsonResult result = await SendJsonAsync(HttpMethod.Get, $"repos/{E(owner)}/{E(name)}/branches/{E(branch)}", credential, null, "branch", ct);
        JsonElement root=result.Document.RootElement;string returned=S(root,"name");string sha=Sha(S(O(root,"commit"),"sha"));bool protectedFlag=B(root,"protected")??false;
        RepositoryRuleSummary rules=await TryGetRulesAsync(owner,name,branch,credential,ct);
        return new RepositoryProviderBranchDetail(returned,sha,protectedFlag,rules);
    }

    public async Task<IReadOnlyList<RepositoryProviderTag>> ListTagsAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, int page, int pageSize, CancellationToken ct = default)
    {
        using RepositoryCredentialLease credential = await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId, envId, secretId, ct);
        using GitHubJsonResult result = await SendJsonAsync(HttpMethod.Get,$"repos/{E(owner)}/{E(name)}/tags?page={page}&per_page={pageSize}",credential,null,"tags",ct);
        if(result.Document.RootElement.ValueKind!=JsonValueKind.Array)throw InvalidResponse();
        return result.Document.RootElement.EnumerateArray().Select(x=>new RepositoryProviderTag(S(x,"name"),Sha(S(O(x,"commit"),"sha")))).ToArray();
    }

    public async Task<IReadOnlyList<RepositoryProviderCommit>> ListCommitsAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, string exactCommitSha, string? path, int page, int pageSize, CancellationToken ct = default)
    {
        string sha=Sha(exactCommitSha);string relative=$"repos/{E(owner)}/{E(name)}/commits?sha={E(sha)}&page={page}&per_page={pageSize}"+(string.IsNullOrWhiteSpace(path)?string.Empty:$"&path={E(path)}");
        using RepositoryCredentialLease credential=await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId,envId,secretId,ct);using GitHubJsonResult result=await SendJsonAsync(HttpMethod.Get,relative,credential,null,"commits",ct);
        if(result.Document.RootElement.ValueKind!=JsonValueKind.Array)throw InvalidResponse();
        return result.Document.RootElement.EnumerateArray().Select(ParseCommitSummaryOnly).ToArray();
    }

    public async Task<RepositoryProviderCommit> GetCommitAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, string exactCommitSha, CancellationToken ct = default)
    {
        string sha=Sha(exactCommitSha);using RepositoryCredentialLease credential=await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId,envId,secretId,ct);using GitHubJsonResult result=await SendJsonAsync(HttpMethod.Get,$"repos/{E(owner)}/{E(name)}/commits/{E(sha)}",credential,null,"commit",ct);RepositoryProviderCommit commit=ParseCommit(result.Document.RootElement);if(!string.Equals(commit.Sha,sha,StringComparison.OrdinalIgnoreCase))throw InvalidResponse();return commit;
    }

    public async Task<RepositoryProviderCompare> CompareAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, string baseSha, string headSha, CancellationToken ct = default)
    {
        string b=Sha(baseSha),h=Sha(headSha);string relative=$"repos/{E(owner)}/{E(name)}/compare/{E(b)}...{E(h)}";using RepositoryCredentialLease credential=await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId,envId,secretId,ct);
        using GitHubJsonResult result=await SendJsonAsync(HttpMethod.Get,relative,credential,null,"compare",ct);JsonElement root=result.Document.RootElement;
        string rb=Sha(S(O(root,"base_commit"),"sha"));string rh=Sha(S(O(root,"merge_base_commit"),"sha"));_ = rh;
        string status=S(root,"status");int ahead=I(root,"ahead_by"),behind=I(root,"behind_by"),total=I(root,"total_commits");
        var commits=new List<RepositoryProviderCommit>();if(root.TryGetProperty("commits",out JsonElement cs)&&cs.ValueKind==JsonValueKind.Array){foreach(JsonElement c in cs.EnumerateArray().Take(RepositoryHistoryLimits.MaxCompareCommits))commits.Add(ParseCommitSummaryOnly(c));}
        bool commitsTruncated=root.TryGetProperty("commits",out JsonElement ca)&&ca.ValueKind==JsonValueKind.Array&&ca.GetArrayLength()>RepositoryHistoryLimits.MaxCompareCommits;
        var files=new List<RepositoryCommitFile>();bool filesTruncated=false;if(root.TryGetProperty("files",out JsonElement fs)&&fs.ValueKind==JsonValueKind.Array){filesTruncated=fs.GetArrayLength()>RepositoryHistoryLimits.MaxCompareFiles;foreach(JsonElement f in fs.EnumerateArray().Take(RepositoryHistoryLimits.MaxCompareFiles))files.Add(ParseFile(f));}
        string diff=await SendTextAsync(relative,credential,"application/vnd.github.diff",ct);bool diffTruncated=diff.Length>RepositoryHistoryLimits.MaxUnifiedDiffCharacters;if(diffTruncated)diff=diff[..RepositoryHistoryLimits.MaxUnifiedDiffCharacters];
        return new RepositoryProviderCompare(rb,h,status,ahead,behind,total,commits,files,commitsTruncated,filesTruncated,diff,diffTruncated);
    }

    public async Task<RepositoryProviderBlame> GetBlameAsync(Guid projectId, Guid envId, Guid secretId, string owner, string name, string exactCommitSha, string path, CancellationToken ct = default)
    {
        string sha=Sha(exactCommitSha);using RepositoryCredentialLease credential=await _credentialResolver.ResolveGitHubFineGrainedPatAsync(projectId,envId,secretId,ct);
        const string query="query($owner:String!,$name:String!,$expression:String!,$path:String!){repository(owner:$owner,name:$name){object(expression:$expression){... on Commit{oid blame(path:$path){ranges{startingLine endingLine commit{oid messageHeadline committedDate author{name email}}}}}}}}";
        string body=JsonSerializer.Serialize(new{query,variables=new{owner,name,expression=sha,path}});using GitHubJsonResult result=await SendJsonAsync(HttpMethod.Post,"graphql",credential,body,"blame",ct);
        JsonElement root=result.Document.RootElement;if(root.TryGetProperty("errors",out JsonElement errors)&&errors.ValueKind==JsonValueKind.Array&&errors.GetArrayLength()>0)throw Failure(RepositoryProviderErrorCodes.ProviderError,"GitHub rejected the blame query.");
        JsonElement repo=O(O(root,"data"),"repository"),obj=O(repo,"object");string oid=Sha(S(obj,"oid"));if(!string.Equals(oid,sha,StringComparison.OrdinalIgnoreCase))throw InvalidResponse();JsonElement ranges=O(obj,"blame").GetProperty("ranges");if(ranges.ValueKind!=JsonValueKind.Array)throw InvalidResponse();
        var list=new List<RepositoryBlameRange>();int lines=0;bool truncated=false;foreach(JsonElement r in ranges.EnumerateArray()){int start=I(r,"startingLine"),end=I(r,"endingLine");if(list.Count>=RepositoryHistoryLimits.MaxBlameRanges||lines+(end-start+1)>RepositoryHistoryLimits.MaxBlameLines){truncated=true;break;}JsonElement c=O(r,"commit");JsonElement? author=c.TryGetProperty("author",out JsonElement a)&&a.ValueKind==JsonValueKind.Object?a:null;list.Add(new RepositoryBlameRange(start,end,Sha(S(c,"oid")),S(c,"messageHeadline"),DT(c,"committedDate"),author.HasValue?SS(author.Value,"name"):null,author.HasValue?SS(author.Value,"email"):null));lines+=end-start+1;}
        return new RepositoryProviderBlame(list,truncated);
    }

    private async Task<RepositoryRuleSummary> TryGetRulesAsync(string owner,string name,string branch,RepositoryCredentialLease credential,CancellationToken ct)
    {
        try{using GitHubJsonResult result=await SendJsonAsync(HttpMethod.Get,$"repos/{E(owner)}/{E(name)}/rules/branches/{E(branch)}",credential,null,"rules",ct);if(result.Document.RootElement.ValueKind!=JsonValueKind.Array)return new(false,false,false,false,true,true,Array.Empty<string>());bool pr=false,checks=false,linear=false,force=true,deletion=true;var required=new List<string>();foreach(JsonElement rule in result.Document.RootElement.EnumerateArray()){string type=SS(rule,"type")??string.Empty;switch(type){case "pull_request":pr=true;break;case "required_status_checks":checks=true;if(rule.TryGetProperty("parameters",out JsonElement p)&&p.ValueKind==JsonValueKind.Object&&p.TryGetProperty("required_status_checks",out JsonElement rs)&&rs.ValueKind==JsonValueKind.Array){foreach(JsonElement x in rs.EnumerateArray()){string? context=SS(x,"context");if(!string.IsNullOrWhiteSpace(context))required.Add(context);}}break;case "required_linear_history":linear=true;break;case "non_fast_forward":force=true;break;case "deletion":deletion=false;break;}}return new(true,pr,checks,linear,force,deletion,required.Distinct(StringComparer.Ordinal).Take(50).ToArray());}
        catch(RepositoryProviderException ex) when(ex.HttpStatusCode is 403 or 404){return new(false,false,false,false,true,true,Array.Empty<string>());}
    }

    private async Task<GitHubJsonResult> SendJsonAsync(HttpMethod method,string relative,RepositoryCredentialLease credential,string? jsonBody,string kind,CancellationToken ct)
    {
        using HttpRequestMessage request=CreateRequest(method,relative,credential,"application/vnd.github+json");if(jsonBody is not null)request.Content=new StringContent(jsonBody,Encoding.UTF8,"application/json");HttpResponseMessage response;try{response=await _httpClient.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,ct);}catch(OperationCanceledException) when(!ct.IsCancellationRequested){throw Failure(RepositoryProviderErrorCodes.NetworkError,"GitHub did not respond within the configured timeout.");}catch(HttpRequestException){throw Failure(RepositoryProviderErrorCodes.NetworkError,"GitHub could not be reached.");}using(response){if(!response.IsSuccessStatusCode)throw MapFailure(response,kind);try{await using Stream stream=await response.Content.ReadAsStreamAsync(ct);JsonDocument doc=await JsonDocument.ParseAsync(stream,cancellationToken:ct);return new GitHubJsonResult(doc);}catch(JsonException){throw InvalidResponse((int)response.StatusCode);}}}
    private async Task<string> SendTextAsync(string relative,RepositoryCredentialLease credential,string accept,CancellationToken ct){using HttpRequestMessage request=CreateRequest(HttpMethod.Get,relative,credential,accept);using HttpResponseMessage response=await _httpClient.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,ct);if(!response.IsSuccessStatusCode)throw MapFailure(response,"diff");string text=await response.Content.ReadAsStringAsync(ct);return text;}
    private static HttpRequestMessage CreateRequest(HttpMethod method,string relative,RepositoryCredentialLease credential,string accept){if(string.IsNullOrWhiteSpace(relative)||relative.Contains("://",StringComparison.Ordinal)||relative.Contains('\\')||relative.Contains('\r')||relative.Contains('\n'))throw Failure(RepositoryProviderErrorCodes.InvalidRepositoryIdentity,"GitHub request path is invalid.");var request=new HttpRequestMessage(method,new Uri(relative,UriKind.Relative));request.Headers.Authorization=new AuthenticationHeaderValue("Bearer",credential.Value);request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue(accept));request.Headers.TryAddWithoutValidation("X-GitHub-Api-Version",GitHubApiVersion);request.Headers.UserAgent.ParseAdd("Dynomax/1.19.0");return request;}
    private static RepositoryProviderCommit ParseCommitSummaryOnly(JsonElement root){string sha=Sha(S(root,"sha"));JsonElement commit=O(root,"commit");string message=S(commit,"message");JsonElement? author=commit.TryGetProperty("author",out JsonElement a)&&a.ValueKind==JsonValueKind.Object?a:null;var parents=new List<string>();if(root.TryGetProperty("parents",out JsonElement ps)&&ps.ValueKind==JsonValueKind.Array)foreach(JsonElement p in ps.EnumerateArray())parents.Add(Sha(S(p,"sha")));return new RepositoryProviderCommit(sha,message,author.HasValue?DT(author.Value,"date"):null,author.HasValue?SS(author.Value,"name"):null,author.HasValue?SS(author.Value,"email"):null,parents,0,0,0,Array.Empty<RepositoryCommitFile>(),false);}
    private static RepositoryProviderCommit ParseCommit(JsonElement root){RepositoryProviderCommit basic=ParseCommitSummaryOnly(root);int adds=0,dels=0,total=0;if(root.TryGetProperty("stats",out JsonElement stats)&&stats.ValueKind==JsonValueKind.Object){adds=I(stats,"additions");dels=I(stats,"deletions");total=I(stats,"total");}var files=new List<RepositoryCommitFile>();bool truncated=false;if(root.TryGetProperty("files",out JsonElement fs)&&fs.ValueKind==JsonValueKind.Array){truncated=fs.GetArrayLength()>RepositoryHistoryLimits.MaxCompareFiles;foreach(JsonElement f in fs.EnumerateArray().Take(RepositoryHistoryLimits.MaxCompareFiles))files.Add(ParseFile(f));}return basic with{Additions=adds,Deletions=dels,TotalChanges=total,Files=files,FilesTruncated=truncated};}
    private static RepositoryCommitFile ParseFile(JsonElement f){string? patch=SS(f,"patch");bool truncated=patch?.Length>RepositoryHistoryLimits.MaxPatchCharactersPerFile;if(truncated==true)patch=patch![..RepositoryHistoryLimits.MaxPatchCharactersPerFile];return new RepositoryCommitFile(S(f,"filename"),S(f,"status"),I(f,"additions"),I(f,"deletions"),I(f,"changes"),SS(f,"previous_filename"),patch,truncated);}
    private static RepositoryProviderException MapFailure(HttpResponseMessage r,string kind){int s=(int)r.StatusCode;if(r.StatusCode==HttpStatusCode.Unauthorized)return Failure(RepositoryProviderErrorCodes.AuthenticationFailed,"GitHub authentication failed.",s);if(r.StatusCode==HttpStatusCode.Forbidden)return Failure(RepositoryProviderErrorCodes.PermissionDenied,"GitHub denied the requested repository history read.",s);if(r.StatusCode==HttpStatusCode.NotFound)return Failure(RepositoryProviderErrorCodes.RepositoryNotFound,$"GitHub {kind} was not found or is not accessible.",s);if(s==429)return Failure(RepositoryProviderErrorCodes.RateLimited,"GitHub rate limit reached.",s);if(s>=500)return Failure(RepositoryProviderErrorCodes.ProviderUnavailable,"GitHub is temporarily unavailable.",s);return Failure(RepositoryProviderErrorCodes.ProviderError,"GitHub rejected the repository history read.",s);}
    private static string Sha(string value){string sha=value?.Trim().ToLowerInvariant()??string.Empty;if(sha.Length is not (40 or 64)||sha.Any(c=>!Uri.IsHexDigit(c)))throw new RepositoryHistoryException(RepositoryHistoryErrorCodes.InvalidCommit,"An exact 40- or 64-character hexadecimal Git object SHA is required.");return sha;}
    private static void ValidateBaseAddress(Uri? u){if(u is null||!u.IsAbsoluteUri||!string.Equals(u.Scheme,Uri.UriSchemeHttps,StringComparison.OrdinalIgnoreCase)||!string.Equals(u.Host,"api.github.com",StringComparison.OrdinalIgnoreCase)||!string.IsNullOrEmpty(u.UserInfo)||(!u.IsDefaultPort&&u.Port!=443))throw new InvalidOperationException("GitHub provider base address must be canonical https://api.github.com/.");}
    private static string E(string v)=>Uri.EscapeDataString(v);private static JsonElement O(JsonElement e,string p)=>e.TryGetProperty(p,out JsonElement v)&&v.ValueKind==JsonValueKind.Object?v:throw InvalidResponse();private static string S(JsonElement e,string p)=>SS(e,p)??throw InvalidResponse();private static string? SS(JsonElement e,string p)=>e.TryGetProperty(p,out JsonElement v)&&v.ValueKind==JsonValueKind.String?v.GetString():null;private static bool? B(JsonElement e,string p)=>e.TryGetProperty(p,out JsonElement v)?v.ValueKind==JsonValueKind.True?true:v.ValueKind==JsonValueKind.False?false:null:null;private static int I(JsonElement e,string p)=>e.TryGetProperty(p,out JsonElement v)&&v.ValueKind==JsonValueKind.Number&&v.TryGetInt32(out int n)?n:0;private static DateTimeOffset? DT(JsonElement e,string p)=>DateTimeOffset.TryParse(SS(e,p),out DateTimeOffset d)?d:null;private static RepositoryProviderException Failure(string c,string m,int? s=null)=>new(c,m,s);private static RepositoryProviderException InvalidResponse(int? s=null)=>Failure(RepositoryProviderErrorCodes.InvalidResponse,"GitHub returned an invalid repository history response.",s);
    private sealed class GitHubJsonResult:IDisposable{public GitHubJsonResult(JsonDocument d)=>Document=d;public JsonDocument Document{get;}public void Dispose()=>Document.Dispose();}
}