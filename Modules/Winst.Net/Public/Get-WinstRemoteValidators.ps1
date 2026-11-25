#Requires -Version 5.1

function Get-WinstRemoteValidators {
    <#
    .SYNOPSIS
        发一次 HEAD 取远端文件的校验器（ETag / Last-Modified / Content-Length），供 files[].refresh 判定使用。
    .OUTPUTS
        @{ Ok; ETag; LastModified; Size; Headers; Error }
    .DESCRIPTION
        元数据类请求：与 HEAD 可用性探测共用「直连 → 代理重试」链。成功结果按 URL、请求头和
        代理尝试序列记入进程内 TTL 缓存；匹配同一次代理尝试时也复用探测的成功响应。
        站点不支持 HEAD、超时或请求失败时，Ok 为 $false，Error 记录原因。
        若校验码尚未确认，调用方在 check 模式下重新下载，其余模式按缓存有效期判断。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Uri,
        [hashtable]$Headers
    )

    $result = @{ Ok = $false; ETag = ''; LastModified = ''; Size = $null; Headers = @{}; Error = '' }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $requestHeaders = $Headers
    if (-not $requestHeaders -or -not $requestHeaders.Count) { $requestHeaders = Get-WinstBrowserHeaders }
    $requestKey = Get-WinstHttpCacheKey -Uri $Uri -Headers $requestHeaders -Method 'Head'
    $cacheKey = 'validators|' + (Get-WinstHeadCacheKey -RequestKey $requestKey -ProxyAttempts $attempts)
    $cached = Get-WinstHttpCacheEntry -Key $cacheKey
    if ($cached) { return $cached.Value }

    $lastError = ''
    foreach ($currentProxy in $attempts) {
        try {
            $head = Invoke-WinstCachedHeadRequest -Uri $Uri -Headers $requestHeaders -Proxy $currentProxy -RequestKey $requestKey

            foreach ($key in $head.Headers.Keys) {
                $result.Headers[$key] = [string]$head.Headers[$key]
            }
            $result.ETag = ([string]$result.Headers['ETag']).Trim()
            $result.LastModified = ([string]$result.Headers['Last-Modified']).Trim()
            $result.Size = $head.Size
            $result.Ok = $true
            break
        } catch {
            $lastError = $_.Exception.Message
        }
    }

    if (-not $result.Ok) { $result.Error = $lastError }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        $note = '失败：' + $result.Error
        if ($result.Ok) {
            $etagText = '无'
            if ($result.ETag) { $etagText = $result.ETag }
            $modifiedText = '无'
            if ($result.LastModified) { $modifiedText = $result.LastModified }
            $sizeText = '无'
            if ($null -ne $result.Size) { $sizeText = [string]$result.Size }
            $note = ('ETag {0} / Last-Modified {1} / 长度 {2}' -f $etagText, $modifiedText, $sizeText)
        }
        Write-Host ('  [verbose] 确认远端文件是否变化 {0} → {1}' -f $Uri, $note) -ForegroundColor DarkGray
    }

    if ($result.Ok) { Set-WinstHttpCacheEntry -Key $cacheKey -Entry @{ At = $head.At; Value = $result } }
    return $result
}
