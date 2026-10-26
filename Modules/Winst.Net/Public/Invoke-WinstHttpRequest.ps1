#Requires -Version 5.1

function Invoke-WinstHttpRequest {
    <#
    .SYNOPSIS
        HTTP GET（元数据类请求）并返回结构化结果 @{ Content; Links; FromCache }。
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
        [int]$TimeoutSec = 30,
        [hashtable]$Headers = $null,
        [string]$Method = 'Get',
        [switch]$NoCache
    )

    $cacheKey = ''
    if (-not $NoCache) {
        # -NoCache 时不构造缓存键（键里要排序请求头，纯属白算）
        $cacheKey = Get-WinstHttpCacheKey -Uri $Uri -Headers $Headers -Method $Method
        $cached = Get-WinstHttpCacheEntry -Key $cacheKey
        if ($cached) { return $cached }
    }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)

    $lastError = $null
    foreach ($currentProxy in $attempts) {
        try {
            $params = @{
                Uri             = $Uri
                UseBasicParsing = $true
                TimeoutSec      = $TimeoutSec
            }
            if ($currentProxy) { $params['Proxy'] = $currentProxy }
            if ($Headers -and $Headers.Count -gt 0) { $params['Headers'] = $Headers }
            if ($Method -and $Method -ine 'Get') { $params['Method'] = $Method }

            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                $headerNote = ''
                if ($Headers -and $Headers.Count -gt 0 -and $Headers.ContainsKey('User-Agent')) { $headerNote = '（浏览器式请求头）' }
                if ($currentProxy) {
                    Write-Host ('  [verbose] GET {0}（代理 {1}）{2}' -f $Uri, $currentProxy, $headerNote) -ForegroundColor DarkGray
                } else {
                    Write-Host ('  [verbose] GET {0}{1}' -f $Uri, $headerNote) -ForegroundColor DarkGray
                }
            }

            $response = Invoke-WebRequest @params
            $text = Get-WinstResponseText -Response $response
            # 只有确实含 <a 标签的响应才解析锚点：清单 JSON 等大文本可省一次全文正则
            $links = @()
            if ($text -match '<a\b') { $links = @(Get-HtmlAnchorList -Html $text) }

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
                Write-Host ('  [verbose] 响应 {0} 字节，锚点 {1} 个：{2}' -f $text.Length, $links.Count, $preview) -ForegroundColor DarkGray
            }

            if (-not $NoCache) { Set-WinstHttpCacheEntry -Key $cacheKey -Content $text -Links $links -FinalUri $finalUri }
            return @{ Content = $text; Links = $links; FinalUri = $finalUri; FromCache = $false }
        } catch {
            $lastError = $_
            if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                Write-Host ('  [verbose] 请求失败: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
            }
        }
    }

    throw $lastError
}
