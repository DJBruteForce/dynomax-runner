using System.Net;
using System.Net.Http.Headers;

namespace Dynomax.Infrastructure.ProjectContext.Repositories;

internal sealed class GitHubRepositoryRetryHandler : DelegatingHandler
{
    private const int MaxAttempts=3; private static readonly TimeSpan MaxDelay=TimeSpan.FromSeconds(30);
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancellationToken)
    {
        if(!IsRetrySafe(request))return await base.SendAsync(request,cancellationToken);
        byte[]? content=request.Content is null?null:await request.Content.ReadAsByteArrayAsync(cancellationToken);List<KeyValuePair<string,IEnumerable<string>>>? contentHeaders=request.Content?.Headers.Select(x=>new KeyValuePair<string,IEnumerable<string>>(x.Key,x.Value)).ToList();
        for(int attempt=1;;attempt++)
        {
            using HttpRequestMessage clone=Clone(request,content,contentHeaders);HttpResponseMessage response;
            try{response=await base.SendAsync(clone,cancellationToken);}catch(HttpRequestException) when(attempt<MaxAttempts){await Task.Delay(Backoff(attempt),cancellationToken);continue;}
            if(!ShouldRetry(response)||attempt>=MaxAttempts)return response;
            TimeSpan delay=RetryDelay(response,attempt);response.Dispose();await Task.Delay(delay,cancellationToken);
        }
    }
    private static bool IsRetrySafe(HttpRequestMessage r){if(r.Method==HttpMethod.Get||r.Method==HttpMethod.Head)return true;if(r.Method!=HttpMethod.Post)return false;string path=r.RequestUri?.OriginalString??string.Empty;return path.Equals("graphql",StringComparison.OrdinalIgnoreCase)||path.EndsWith("/graphql",StringComparison.OrdinalIgnoreCase);}
    private static bool ShouldRetry(HttpResponseMessage r){int code=(int)r.StatusCode;if(code is 429 or 502 or 503 or 504)return true;if(r.StatusCode==HttpStatusCode.Forbidden&&r.Headers.TryGetValues("X-RateLimit-Remaining",out var values)&&values.Any(x=>x.Trim()=="0"))return true;return false;}
    private static TimeSpan RetryDelay(HttpResponseMessage r,int attempt){if(r.Headers.RetryAfter?.Delta is TimeSpan d)return Clamp(d);if(r.Headers.RetryAfter?.Date is DateTimeOffset at)return Clamp(at-DateTimeOffset.UtcNow);if(r.Headers.TryGetValues("X-RateLimit-Reset",out var values)&&long.TryParse(values.FirstOrDefault(),out long seconds)){DateTimeOffset reset=DateTimeOffset.FromUnixTimeSeconds(seconds);return Clamp(reset-DateTimeOffset.UtcNow);}return Backoff(attempt);}
    private static TimeSpan Backoff(int attempt)=>TimeSpan.FromSeconds(Math.Min(MaxDelay.TotalSeconds,Math.Pow(2,Math.Max(0,attempt))));private static TimeSpan Clamp(TimeSpan d)=>d<TimeSpan.Zero?TimeSpan.Zero:d>MaxDelay?MaxDelay:d;
    private static HttpRequestMessage Clone(HttpRequestMessage source,byte[]? content,List<KeyValuePair<string,IEnumerable<string>>>? contentHeaders){var clone=new HttpRequestMessage(source.Method,source.RequestUri){Version=source.Version,VersionPolicy=source.VersionPolicy};foreach(var h in source.Headers)clone.Headers.TryAddWithoutValidation(h.Key,h.Value);if(content is not null){clone.Content=new ByteArrayContent(content);if(contentHeaders is not null)foreach(var h in contentHeaders)clone.Content.Headers.TryAddWithoutValidation(h.Key,h.Value);}return clone;}
}