#Requires -Version 5.1

function Get-WinstCachedHeadSize {
    <#
    .SYNOPSIS
        从当前文件已完成的 HEAD 探测读取总长度，按同一地址、会话请求头和代理匹配。
    #>
    param([hashtable]$Context, [string]$Uri, [hashtable]$Headers)

    if ($Uri -notmatch '^https?://') { return }
    # 常规来源可能用浏览器式默认头或系统默认头探测；浏览器会话只复用自身请求头。
    $headerSets = @($Headers)
    if (-not $Headers -or -not $Headers.Count) { $headerSets = @((Get-WinstBrowserHeaders), $null) }
    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    foreach ($requestHeaders in $headerSets) {
        $requestKey = Get-WinstHttpCacheKey -Uri $Uri -Headers $requestHeaders -Method 'Head'
        foreach ($proxy in $attempts) {
            $head = Invoke-WinstCachedHeadRequest -Uri $Uri -Headers $requestHeaders -Proxy $proxy -RequestKey $requestKey -CachedOnly
            if ($head -and $null -ne $head.Size) { return $head.Size }
        }
    }
}
