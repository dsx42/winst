#Requires -Version 5.1

function Invoke-WinstHttpRequest {
    <#
    .SYNOPSIS
        发送 HTTP GET 或 HEAD 元数据请求并返回结构化结果 @{ Content; Links; FinalUri }。
    .DESCRIPTION
        **元数据类**请求（清单 / 版本页 / 校验文件）：按 `proxyMode` 决定尝试序列。
        这类请求不属于「下载」，`proxyMode = download-direct` 时**只用代理**、不先试直连——
        这类站点通常正是直连打不开才需要代理。
        默认启用进程内 TTL 缓存；
        清单本身刷新传 `-NoCache`。全部尝试失败时抛出最后一次异常，供上层转网络错误退出码。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Context,
        [hashtable]$Headers = $null,
        [string]$Method = 'Get',
        [switch]$NoCache,
        [switch]$TextOnly
    )

    $cacheKey = ''
    if (-not $NoCache) {
        # -NoCache 时不构造缓存键（键里要排序请求头，纯属白算）
        $cacheKey = Get-WinstHttpCacheKey -Uri $Uri -Headers $Headers -Method $Method
        $cached = Get-WinstHttpCacheEntry -Key $cacheKey
        if ($cached) {
            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                $age = ([DateTime]::Now - $cached.At).TotalSeconds
                Write-Host ('  [verbose] 命中进程内缓存（{0} 秒前）: {1}' -f [int]$age, $Uri) -ForegroundColor DarkGray
            }
            if (-not $TextOnly -and $null -eq $cached.Links) {
                $cached.Links = @(Get-HtmlAnchorList -Html $cached.Content)
            }
            return @{ Content = $cached.Content; Links = $cached.Links; FinalUri = $cached.FinalUri }
        }
    }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)

    $lastError = $null
    foreach ($currentProxy in $attempts) {
        try {
            $params = New-WinstHttpRequestParameters -Uri $Uri -TimeoutSec 30 -Method $Method -Headers $Headers -Proxy $currentProxy

            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                $headerNote = ''
                if ($Headers -and $Headers.Count -gt 0 -and $Headers.ContainsKey('User-Agent')) { $headerNote = '（浏览器式请求头）' }
                if ($currentProxy) {
                    Write-Host ('  [verbose] {0} {1}（代理 {2}）{3}' -f $Method.ToUpperInvariant(), $Uri, $currentProxy, $headerNote) -ForegroundColor DarkGray
                } else {
                    Write-Host ('  [verbose] {0} {1}{2}' -f $Method.ToUpperInvariant(), $Uri, $headerNote) -ForegroundColor DarkGray
                }
            }

            $response = Invoke-WebRequest @params
            $text = Get-WinstResponseText -Response $response
            # 只有确实含 <a 标签的响应才解析锚点：清单 JSON 等大文本可省一次全文正则
            $links = $null
            if (-not $TextOnly) {
                $links = @()
                if ($text -match '<a\b') { $links = @(Get-HtmlAnchorList -Html $text) }
            }

            # 跟随重定向后的最终地址（如 releases/latest 会跳到 releases/tag/<tag>）
            $finalUri = ''
            try {
                $baseResponse = $response.BaseResponse
                if ($baseResponse -and $baseResponse.ResponseUri) {
                    $finalUri = [string]$baseResponse.ResponseUri.AbsoluteUri
                }
            } catch {
                $finalUri = ''
            }

            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                $preview = $text
                if ($preview.Length -gt 120) { $preview = $preview.Substring(0, 120) + '…' }
                $preview = $preview -replace '\s+', ' '
                Write-Host ('  [verbose] 响应 {0} 字符，锚点 {1} 个：{2}' -f $text.Length, @($links | Where-Object { $null -ne $_ }).Count, $preview) -ForegroundColor DarkGray
            }

            if (-not $NoCache) { Set-WinstHttpCacheEntry -Key $cacheKey -Entry @{ Content = $text; Links = $links; FinalUri = $finalUri } }
            return @{ Content = $text; Links = $links; FinalUri = $finalUri }
        } catch {
            $lastError = $_
            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                Write-Host ('  [verbose] 请求失败: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
            }
        }
    }

    throw $lastError
}
