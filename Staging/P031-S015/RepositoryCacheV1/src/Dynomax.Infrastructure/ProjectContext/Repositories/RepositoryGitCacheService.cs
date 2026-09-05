using System.Collections.Concurrent;
using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Dynomax.Domain.ProjectContext;
using Dynomax.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal static class RepositoryGitCacheErrorCodes
{
    public const string NotFound = "REPOSITORY_CACHE_NOT_FOUND";
    public const string PolicyDenied = "REPOSITORY_CACHE_POLICY_DENIED";
    public const string InvalidRemote = "REPOSITORY_CACHE_INVALID_REMOTE";
    public const string FetchFailed = "REPOSITORY_CACHE_FETCH_FAILED";
    public const string RateLimited = "REPOSITORY_CACHE_RATE_LIMITED";
    public const string RepositoryTooLarge = "REPOSITORY_CACHE_REPOSITORY_TOO_LARGE";
    public const string ProjectRefreshTooLarge = "REPOSITORY_CACHE_PROJECT_REFRESH_TOO_LARGE";
    public const string StorageUnavailable = "REPOSITORY_CACHE_STORAGE_UNAVAILABLE";
}

internal sealed class RepositoryGitCacheException : InvalidOperationException
{
    public RepositoryGitCacheException(string code,string message,DateTimeOffset? retryAtUtc=null):base(message){Code=code;RetryAtUtc=retryAtUtc;}
    public string Code{get;} public DateTimeOffset? RetryAtUtc{get;}
}

internal sealed record RepositoryGitCacheSnapshot(Guid RepositoryContextId,string ProviderRepositoryId,string FullName,string MirrorPath,string RemoteUrl,DateTimeOffset LastFetchAtUtc,DateTimeOffset LastAccessAtUtc,long SizeBytes,bool Refreshed,bool Rebuilt);
internal sealed record RepositoryGitCacheMetadata(int SchemaVersion,Guid RepositoryContextId,string Provider,string ProviderRepositoryId,string FullName,string RemoteUrl,DateTimeOffset CreatedAtUtc,DateTimeOffset LastFetchAtUtc,DateTimeOffset LastAccessAtUtc,long SizeBytes);

internal interface IRepositoryGitCacheService
{
    Task<RepositoryGitCacheSnapshot> EnsureAsync(Guid projectId,Guid projectEnvironmentId,Guid repositoryContextId,bool forceRefresh=false,CancellationToken cancellationToken=default);
    Task<IReadOnlyList<RepositoryGitCacheSnapshot>> RefreshManyAsync(Guid projectId,Guid projectEnvironmentId,IReadOnlyCollection<Guid>? repositoryContextIds=null,CancellationToken cancellationToken=default);
    Task<bool> DeleteAsync(Guid projectId,Guid repositoryContextId,CancellationToken cancellationToken=default);
}

internal sealed class RepositoryGitCacheService : IRepositoryGitCacheService
{
    private const string Section="Dynomax:RepositoryCache";
    internal const int MaxTreeEntries=100000; internal const int MaxSearchFiles=20000; internal const long MaxSearchBytes=67108864; internal const long MaxFileBytes=2097152; internal const int MaxDiffCharacters=1000000;
    private static readonly ConcurrentDictionary<string,SemaphoreSlim> RepositoryLocks=new(StringComparer.OrdinalIgnoreCase);
    private static readonly SemaphoreSlim CleanupLock=new(1,1);
    private readonly DynomaxDbContext _db; private readonly IRepositoryCredentialResolver _credentials; private readonly IConfiguration _configuration;
    public RepositoryGitCacheService(DynomaxDbContext db,IRepositoryCredentialResolver credentials,IConfiguration configuration){_db=db;_credentials=credentials;_configuration=configuration;}

    public async Task<RepositoryGitCacheSnapshot> EnsureAsync(Guid projectId,Guid projectEnvironmentId,Guid repositoryContextId,bool forceRefresh=false,CancellationToken cancellationToken=default)
    {
        Target t=await LoadAsync(projectId,repositoryContextId,cancellationToken);string remote=CanonicalCloneUrl(t.Repository);Settings s=ReadSettings();string key=CacheKey(t.Repository,remote);SemaphoreSlim gate=RepositoryLocks.GetOrAdd(key,_=>new SemaphoreSlim(1,1));await gate.WaitAsync(cancellationToken);
        try{return await EnsureLockedAsync(projectEnvironmentId,t.Repository,remote,key,s,forceRefresh,cancellationToken);}finally{gate.Release();}
    }

    public async Task<IReadOnlyList<RepositoryGitCacheSnapshot>> RefreshManyAsync(Guid projectId,Guid projectEnvironmentId,IReadOnlyCollection<Guid>? repositoryContextIds=null,CancellationToken cancellationToken=default)
    {
        Settings s=ReadSettings();Guid? sourceId=await _db.ProjectContextSources.AsNoTracking().Where(x=>x.ProjectId==projectId&&x.SourceType==ProjectContextSourceTypes.GitRepositories&&x.IsActive).Select(x=>(Guid?)x.Id).SingleOrDefaultAsync(cancellationToken);if(!sourceId.HasValue)return Array.Empty<RepositoryGitCacheSnapshot>();
        IQueryable<ProjectContextRepository> q=_db.ProjectContextRepositories.AsNoTracking().Where(x=>x.SourceId==sourceId.Value&&x.IsActive);if(repositoryContextIds is{Count:>0}){Guid[] ids=repositoryContextIds.Distinct().ToArray();if(ids.Length>s.MaxProjectRefreshRepositories)throw Failure(RepositoryGitCacheErrorCodes.ProjectRefreshTooLarge,"Repository refresh selection exceeds the configured bound.");q=q.Where(x=>ids.Contains(x.Id));}
        Guid[] targets=await q.OrderBy(x=>x.FullName).Select(x=>x.Id).Take(s.MaxProjectRefreshRepositories+1).ToArrayAsync(cancellationToken);if(targets.Length>s.MaxProjectRefreshRepositories)throw Failure(RepositoryGitCacheErrorCodes.ProjectRefreshTooLarge,"Project repository refresh exceeds the configured bound.");
        using var parallel=new SemaphoreSlim(s.MaxConcurrentRefreshes,s.MaxConcurrentRefreshes);var tasks=targets.Select(async id=>{await parallel.WaitAsync(cancellationToken);try{return await EnsureAsync(projectId,projectEnvironmentId,id,true,cancellationToken);}finally{parallel.Release();}}).ToArray();return await Task.WhenAll(tasks);
    }

    public async Task<bool> DeleteAsync(Guid projectId,Guid repositoryContextId,CancellationToken cancellationToken=default)
    {
        Target t=await LoadAsync(projectId,repositoryContextId,cancellationToken);string remote=CanonicalCloneUrl(t.Repository);Settings s=ReadSettings();string key=CacheKey(t.Repository,remote);SemaphoreSlim gate=RepositoryLocks.GetOrAdd(key,_=>new SemaphoreSlim(1,1));await gate.WaitAsync(cancellationToken);try{string item=ItemPath(s,key);if(!Directory.Exists(item))return false;DeleteDirectory(item);return true;}finally{gate.Release();}
    }

    private async Task<RepositoryGitCacheSnapshot> EnsureLockedAsync(Guid environmentId,ProjectContextRepository repo,string remote,string key,Settings s,bool force,CancellationToken ct)
    {
        Directory.CreateDirectory(s.RootPath);string item=ItemPath(s,key),mirror=Path.Combine(item,"mirror.git"),metaPath=Path.Combine(item,"metadata.json");RepositoryGitCacheMetadata? meta=ReadMetadata(metaPath);DateTimeOffset now=DateTimeOffset.UtcNow;
        if(!force&&Directory.Exists(mirror)&&meta is not null&&now-meta.LastFetchAtUtc<=s.FreshFor){meta=meta with{LastAccessAtUtc=now,SizeBytes=DirectoryBytes(item)};WriteMetadata(metaPath,meta);return Snapshot(repo,mirror,meta,false,false);}
        await PruneAsync(s,item,ct);bool rebuilt=false;
        using RepositoryCredentialLease credential=await _credentials.ResolveGitHubFineGrainedPatAsync(await ProjectIdForRepositoryAsync(repo.SourceId,ct),environmentId,repo.CredentialSecretReferenceId,ct);
        if(!Directory.Exists(mirror)){rebuilt=true;string temp=item+".creating-"+Guid.NewGuid().ToString("N");DeleteDirectory(temp);Directory.CreateDirectory(temp);try{await GitCloneMirrorAsync(remote,Path.Combine(temp,"mirror.git"),credential,s,ct);Directory.CreateDirectory(temp);long bytes=DirectoryBytes(temp);if(bytes>s.MaxRepositoryBytes)throw Failure(RepositoryGitCacheErrorCodes.RepositoryTooLarge,"Repository mirror exceeds the configured per-repository cache bound.");var created=new RepositoryGitCacheMetadata(1,repo.Id,repo.Provider,repo.ProviderRepositoryId,repo.FullName,remote,now,now,now,bytes);WriteMetadata(Path.Combine(temp,"metadata.json"),created);if(Directory.Exists(item))DeleteDirectory(item);Directory.Move(temp,item);mirror=Path.Combine(item,"mirror.git");metaPath=Path.Combine(item,"metadata.json");meta=created;}catch{DeleteDirectory(temp);throw;}}
        else{await GitFetchMirrorAsync(mirror,remote,credential,s,ct);long bytes=DirectoryBytes(item);if(bytes>s.MaxRepositoryBytes){DeleteDirectory(item);throw Failure(RepositoryGitCacheErrorCodes.RepositoryTooLarge,"Repository mirror exceeds the configured per-repository cache bound and was evicted.");}meta=(meta??new RepositoryGitCacheMetadata(1,repo.Id,repo.Provider,repo.ProviderRepositoryId,repo.FullName,remote,now,now,now,bytes)) with{LastFetchAtUtc=now,LastAccessAtUtc=now,SizeBytes=bytes,RemoteUrl=remote,FullName=repo.FullName};WriteMetadata(metaPath,meta);}
        await PruneAsync(s,item,ct);meta??=ReadMetadata(metaPath)??throw Failure(RepositoryGitCacheErrorCodes.StorageUnavailable,"Repository cache metadata is unavailable.");return Snapshot(repo,mirror,meta,true,rebuilt);
    }

    private async Task<Target> LoadAsync(Guid projectId,Guid repositoryContextId,CancellationToken ct){if(projectId==Guid.Empty||repositoryContextId==Guid.Empty)throw Failure(RepositoryGitCacheErrorCodes.NotFound,"Repository context was not found.");Guid? sourceId=await _db.ProjectContextSources.AsNoTracking().Where(x=>x.ProjectId==projectId&&x.SourceType==ProjectContextSourceTypes.GitRepositories&&x.IsActive).Select(x=>(Guid?)x.Id).SingleOrDefaultAsync(ct);if(!sourceId.HasValue)throw Failure(RepositoryGitCacheErrorCodes.NotFound,"Repository context was not found.");ProjectContextRepository? repo=await _db.ProjectContextRepositories.AsNoTracking().SingleOrDefaultAsync(x=>x.Id==repositoryContextId&&x.SourceId==sourceId.Value&&x.IsActive,ct);if(repo is null)throw Failure(RepositoryGitCacheErrorCodes.NotFound,"Repository context was not found.");ProjectContextRepositoryPolicy? policy=await _db.ProjectContextRepositoryPolicies.AsNoTracking().SingleOrDefaultAsync(x=>x.RepositoryContextId==repositoryContextId,ct);if(policy?.AllowRead!=true)throw Failure(RepositoryGitCacheErrorCodes.PolicyDenied,"Repository cache access is denied by effective repository policy.");if(!string.Equals(repo.Provider,RepositoryProviders.GitHub,StringComparison.Ordinal))throw Failure(RepositoryGitCacheErrorCodes.InvalidRemote,"Repository provider is not supported by the Git cache.");return new Target(repo);}
    private async Task<Guid> ProjectIdForRepositoryAsync(Guid sourceId,CancellationToken ct){Guid id=await _db.ProjectContextSources.AsNoTracking().Where(x=>x.Id==sourceId).Select(x=>x.ProjectId).SingleOrDefaultAsync(ct);if(id==Guid.Empty)throw Failure(RepositoryGitCacheErrorCodes.NotFound,"Repository Project is unavailable.");return id;}

    private async Task GitCloneMirrorAsync(string remote,string mirror,RepositoryCredentialLease credential,Settings s,CancellationToken ct)=>await RunGitWithRetryAsync(new[]{"clone","--mirror","--",remote,mirror},null,credential,s,ct);
    private async Task GitFetchMirrorAsync(string mirror,string remote,RepositoryCredentialLease credential,Settings s,CancellationToken ct){await RunGitWithRetryAsync(new[]{"--git-dir",mirror,"remote","set-url","origin",remote},null,null,s,ct);await RunGitWithRetryAsync(new[]{"--git-dir",mirror,"fetch","--prune","--tags","origin","+refs/heads/*:refs/heads/*"},null,credential,s,ct);}
    private static async Task RunGitWithRetryAsync(string[] args,string? workingDirectory,RepositoryCredentialLease? credential,Settings s,CancellationToken ct){for(int attempt=1;;attempt++){GitResult r=await RunGitAsync(args,workingDirectory,credential,s.FetchTimeout,ct);if(r.ExitCode==0)return;bool transient=IsTransient(r.SafeError);if(!transient||attempt>=s.MaxFetchAttempts)throw Failure(transient&&IsRateLimit(r.SafeError)?RepositoryGitCacheErrorCodes.RateLimited:RepositoryGitCacheErrorCodes.FetchFailed,transient?"GitHub repository fetch did not succeed after bounded retries.":"Git repository operation failed.",transient?DateTimeOffset.UtcNow+DelayFor(attempt,s):null);await Task.Delay(DelayFor(attempt,s),ct);}}
    private static async Task<GitResult> RunGitAsync(string[] args,string? workingDirectory,RepositoryCredentialLease? credential,TimeSpan timeout,CancellationToken ct){var psi=new ProcessStartInfo("git"){UseShellExecute=false,RedirectStandardOutput=true,RedirectStandardError=true,CreateNoWindow=true,WorkingDirectory=workingDirectory??string.Empty};foreach(string arg in args)psi.ArgumentList.Add(arg);psi.Environment["GIT_TERMINAL_PROMPT"]="0";psi.Environment["GCM_INTERACTIVE"]="Never";psi.Environment["GIT_CONFIG_NOSYSTEM"]="1";if(credential is not null){string basic=Convert.ToBase64String(Encoding.UTF8.GetBytes("x-access-token:"+credential.Value));psi.Environment["GIT_CONFIG_COUNT"]="1";psi.Environment["GIT_CONFIG_KEY_0"]="http.extraHeader";psi.Environment["GIT_CONFIG_VALUE_0"]="Authorization: Basic "+basic;}using var process=new Process{StartInfo=psi};try{if(!process.Start())throw Failure(RepositoryGitCacheErrorCodes.FetchFailed,"Git process could not be started.");var stdout=process.StandardOutput.ReadToEndAsync(ct);var stderr=process.StandardError.ReadToEndAsync(ct);using var linked=CancellationTokenSource.CreateLinkedTokenSource(ct);linked.CancelAfter(timeout);await process.WaitForExitAsync(linked.Token);string err=await stderr;_ = await stdout;return new GitResult(process.ExitCode,credential?.Redact(err)??err);}catch(OperationCanceledException) when(!ct.IsCancellationRequested){TryKill(process);return new GitResult(124,"git operation timed out");}catch(System.ComponentModel.Win32Exception){throw Failure(RepositoryGitCacheErrorCodes.FetchFailed,"Git executable is unavailable.");}}
    private async Task PruneAsync(Settings s,string protectedItem,CancellationToken ct){await CleanupLock.WaitAsync(ct);try{if(!Directory.Exists(s.RootPath))return;var items=Directory.GetDirectories(s.RootPath).Where(x=>!string.Equals(Path.GetFullPath(x),Path.GetFullPath(protectedItem),StringComparison.OrdinalIgnoreCase)).Select(x=>new{Path=x,Meta=ReadMetadata(Path.Combine(x,"metadata.json")),Size=DirectoryBytes(x)}).OrderBy(x=>x.Meta?.LastAccessAtUtc??new DateTimeOffset(Directory.GetLastWriteTimeUtc(x.Path))).ToList();long total=Directory.GetDirectories(s.RootPath).Sum(x=>DirectoryBytes(x));foreach(var item in items){if(total<=s.MaxTotalBytes)break;DeleteDirectory(item.Path);total-=item.Size;}}finally{CleanupLock.Release();}}
    private Settings ReadSettings(){string root=_configuration[$"{Section}:RootPath"]??Path.Combine(Path.GetTempPath(),"Dynomax","RepositoryCache");root=Path.GetFullPath(root);return new Settings(root,ReadLong("MaxTotalBytes",21474836480L,268435456L,1099511627776L),ReadLong("MaxRepositoryBytes",5368709120L,67108864L,536870912000L),TimeSpan.FromSeconds(ReadInt("FreshForSeconds",120,5,3600)),TimeSpan.FromSeconds(ReadInt("FetchTimeoutSeconds",180,10,1800)),ReadInt("MaxFetchAttempts",3,1,5),TimeSpan.FromSeconds(ReadInt("RetryBaseSeconds",2,1,30)),TimeSpan.FromSeconds(ReadInt("RetryMaxSeconds",30,1,120)),ReadInt("MaxProjectRefreshRepositories",50,1,500),ReadInt("MaxConcurrentRefreshes",4,1,16));}
    private int ReadInt(string key,int fallback,int min,int max)=>int.TryParse(_configuration[$"{Section}:{key}"],out int v)?Math.Clamp(v,min,max):fallback;private long ReadLong(string key,long fallback,long min,long max)=>long.TryParse(_configuration[$"{Section}:{key}"],out long v)?Math.Clamp(v,min,max):fallback;
    private static string CanonicalCloneUrl(ProjectContextRepository repo){if(!Uri.TryCreate(repo.CloneUrl,UriKind.Absolute,out Uri? u)||u.Scheme!=Uri.UriSchemeHttps||!string.Equals(u.Host,"github.com",StringComparison.OrdinalIgnoreCase)||!string.IsNullOrEmpty(u.UserInfo)||(!u.IsDefaultPort&&u.Port!=443)||u.Query.Length>0||u.Fragment.Length>0)throw Failure(RepositoryGitCacheErrorCodes.InvalidRemote,"Repository clone URL must be canonical credential-free GitHub HTTPS.");string expected="/"+repo.Owner+"/"+repo.Name+".git";if(!string.Equals(u.AbsolutePath,expected,StringComparison.Ordinal))throw Failure(RepositoryGitCacheErrorCodes.InvalidRemote,"Repository clone URL does not match the connected repository identity.");return $"https://github.com/{repo.Owner}/{repo.Name}.git";}
    private static string CacheKey(ProjectContextRepository repo,string remote){string id=new string(repo.ProviderRepositoryId.Where(char.IsLetterOrDigit).Take(40).ToArray());if(id.Length==0)id="repo";string hash=Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(repo.Provider+"|"+repo.ProviderRepositoryId+"|"+remote))).ToLowerInvariant()[..16];return $"github-{id}-{hash}";}
    private static string ItemPath(Settings s,string key){string path=Path.GetFullPath(Path.Combine(s.RootPath,key));string root=s.RootPath.TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;if(!path.StartsWith(root,StringComparison.OrdinalIgnoreCase))throw Failure(RepositoryGitCacheErrorCodes.StorageUnavailable,"Repository cache path escaped the configured root.");return path;}
    private static void WriteMetadata(string path,RepositoryGitCacheMetadata m){Directory.CreateDirectory(Path.GetDirectoryName(path)!);string temp=path+".tmp";File.WriteAllText(temp,JsonSerializer.Serialize(m),new UTF8Encoding(false));File.Move(temp,path,true);}private static RepositoryGitCacheMetadata? ReadMetadata(string path){try{return File.Exists(path)?JsonSerializer.Deserialize<RepositoryGitCacheMetadata>(File.ReadAllText(path)):null;}catch{return null;}}
    private static long DirectoryBytes(string path){try{return Directory.Exists(path)?Directory.EnumerateFiles(path,"*",SearchOption.AllDirectories).Sum(x=>{try{return new FileInfo(x).Length;}catch{return 0L;}}):0;}catch{return 0;}}
    private static void DeleteDirectory(string path){try{if(Directory.Exists(path)){foreach(string f in Directory.EnumerateFiles(path,"*",SearchOption.AllDirectories)){try{File.SetAttributes(f,FileAttributes.Normal);}catch{}}Directory.Delete(path,true);}}catch(IOException){}catch(UnauthorizedAccessException){}}
    private static bool IsRateLimit(string text){string s=text.ToLowerInvariant();return s.Contains("429")||s.Contains("rate limit")||s.Contains("secondary rate");}private static bool IsTransient(string text){string s=text.ToLowerInvariant();return IsRateLimit(s)||s.Contains("502")||s.Contains("503")||s.Contains("504")||s.Contains("timed out")||s.Contains("could not resolve host")||s.Contains("connection reset")||s.Contains("remote end hung up");}
    private static TimeSpan DelayFor(int attempt,Settings s){double seconds=Math.Min(s.RetryMax.TotalSeconds,s.RetryBase.TotalSeconds*Math.Pow(2,Math.Max(0,attempt-1)));return TimeSpan.FromSeconds(seconds);}private static void TryKill(Process p){try{if(!p.HasExited)p.Kill(true);}catch{}}
    private static RepositoryGitCacheSnapshot Snapshot(ProjectContextRepository repo,string mirror,RepositoryGitCacheMetadata meta,bool refreshed,bool rebuilt)=>new(repo.Id,repo.ProviderRepositoryId,repo.FullName,mirror,meta.RemoteUrl,meta.LastFetchAtUtc,meta.LastAccessAtUtc,meta.SizeBytes,refreshed,rebuilt);
    private static RepositoryGitCacheException Failure(string code,string message,DateTimeOffset? retryAtUtc=null)=>new(code,message,retryAtUtc);
    private sealed record Target(ProjectContextRepository Repository);private sealed record GitResult(int ExitCode,string SafeError);private sealed record Settings(string RootPath,long MaxTotalBytes,long MaxRepositoryBytes,TimeSpan FreshFor,TimeSpan FetchTimeout,int MaxFetchAttempts,TimeSpan RetryBase,TimeSpan RetryMax,int MaxProjectRefreshRepositories,int MaxConcurrentRefreshes);
}