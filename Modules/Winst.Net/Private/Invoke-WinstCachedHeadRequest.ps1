#Requires -Version 5.1

function Invoke-WinstCachedHeadRequest {
    <#
    .SYNOPSIS
        执行一次 HEAD，只在请求条件相同的探测之间复用成功响应。
    #>
    param([string]$Uri, [hashtable]$Headers, [string]$Proxy, [string]$RequestKey, [switch]$CachedOnly)

    # 按实际代理尝试缓存，调用方仍独立判断失败时是否换代理。
    $key = 'head-response|' + (Get-WinstHeadCacheKey -RequestKey $RequestKey -ProxyAttempts $Proxy)
    $cached = Get-WinstHttpCacheEntry -Key $key
    if ($cached -or $CachedOnly) { return $cached }

    $params = New-WinstHttpRequestParameters -Uri $Uri -Method 'Head' -TimeoutSec 20 -Headers $Headers -Proxy $Proxy
    $response = Invoke-WebRequest @params
    $head = @{ Headers = $response.Headers; FinalUri = [string]$response.BaseResponse.ResponseUri.AbsoluteUri }
    $head.Size = Get-WinstResponseFileSize -StatusCode $response.StatusCode -ContentLength $response.Headers['Content-Length'] -ContentRange $response.Headers['Content-Range']
    Set-WinstHttpCacheEntry -Key $key -Entry $head
    return $head
}
