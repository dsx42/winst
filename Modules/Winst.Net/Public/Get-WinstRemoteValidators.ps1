#Requires -Version 5.1

function Get-WinstRemoteValidators {
    <#
    .SYNOPSIS
        发一次 HEAD 取远端文件的校验器（ETag / Last-Modified / Content-Length），供 files[].refresh 判定使用。
    .OUTPUTS
        @{ Ok; ETag; LastModified; Size; Headers; Error }
    .DESCRIPTION
        元数据类请求：与 HEAD 可用性探测共用「直连 → 代理重试」链。成功结果按 URL、请求头、超时和
        代理尝试序列记入进程内 TTL 缓存；匹配同一次代理尝试时也复用探测的成功响应。
        站点不支持 HEAD、超时、代理失败、4xx/5xx 时 Ok = $false 并给出原因；**这一点不视为失败**：
        调用方按 8.4 的兜底策略继续（check 按重取处理、其余退到 TTL 兜底），不否定缓存（见 12）。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Uri,
        [int]$TimeoutSec = 20
    )

    $result = @{ Ok = $false; ETag = ''; LastModified = ''; Size = $null; Headers = @{}; Error = '' }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $requestHeaders = Get-WinstBrowserHeaders
    $requestKey = Get-WinstHttpCacheKey -Uri $Uri -Headers $requestHeaders -Method 'Head'
    $cacheKey = 'validators|' + (Get-WinstHeadCacheKey -RequestKey $requestKey -TimeoutSec $TimeoutSec -ProxyAttempts $attempts)
    $cached = Get-WinstHttpCacheEntry -Key $cacheKey
    if ($cached) { return $cached.Value }

    $lastError = ''
    foreach ($currentProxy in $attempts) {
        try {
            $head = Invoke-WinstCachedHeadRequest -Uri $Uri -TimeoutSec $TimeoutSec -Headers $requestHeaders -Proxy $currentProxy -RequestKey $requestKey

            foreach ($key in $head.Headers.Keys) {
                $result.Headers[$key] = [string]$head.Headers[$key]
            }
            $result.ETag = ([string]$result.Headers['ETag']).Trim()
            $result.LastModified = ([string]$result.Headers['Last-Modified']).Trim()
            $length = 0L
            if ([long]::TryParse([string]$result.Headers['Content-Length'], [ref]$length)) { $result.Size = $length }
            $result.Ok = $true
            $lastError = ''
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
