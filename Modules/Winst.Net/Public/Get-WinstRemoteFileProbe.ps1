#Requires -Version 5.1

function Get-WinstRemoteFileProbe {
    <#
    .SYNOPSIS
        探测远程文件是否存在（HEAD 请求）。
    .DESCRIPTION
        用于校验解析出的安装包地址是否真的可以下载（历史问题：版本列表页会提前出现尚未发布正式包的版本目录，
        如 python.org 的 3.15.0 目录此时只有 alpha 包）。代理行为与其它元数据请求一致，结果按 URL、请求头、
        代理尝试序列和最终地址校验条件记入进程内 TTL 缓存；只缓存确定存在 / 不存在的结果。
        FinalUriMustContain：传入版本号时，200 还要再核对「重定向后的最终地址仍然包含它」——部分站点
        （如 SourceForge 的 /download）对不存在的文件不回 404，而是 302 回项目文件根目录并返回 200 的
        HTML 错误页，只看状态码会误判成存在。

        三态之外还有第四态 blocked：JetBrains 的中国 CDN 对非浏览器客户端回的是「404 + 人机校验页」，
        文件实际存在（浏览器 / 下载引擎都能下）。把它判成 missing 会让刷新误报「清单地址已失效」，
        所以单独拿出来，由调用方按「未能确认」处理（判定见 Test-WinstBotChallengeResponse）。
    .OUTPUTS
        @{ State }
        State  = 'ok'       存在
                 'missing'  确认不存在（404 / 410，或重定向后最终地址不包含 FinalUriMustContain）
                 'blocked'  站点的人机校验把请求拦下了，无法判断（不代表文件不存在）
                 'unknown'  其它无法判断（网络失败、代理不通、服务器不支持 HEAD）
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Context,
        [hashtable]$Headers = $null,
        [string]$FinalUriMustContain = ''
    )

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $requestKey = Get-WinstHttpCacheKey -Uri $Uri -Headers $Headers -Method 'Head'
    $cacheKey = 'probe|{0}:{1}|{2}' -f $FinalUriMustContain.Length, $FinalUriMustContain,
        (Get-WinstHeadCacheKey -RequestKey $requestKey -ProxyAttempts $attempts)
    $cached = Get-WinstHttpCacheEntry -Key $cacheKey
    if ($cached) { return @{ State = $cached.State } }

    $state = 'unknown'
    foreach ($currentProxy in $attempts) {
        $head = $null
        try {
            $head = Invoke-WinstCachedHeadRequest -Uri $Uri -Headers $Headers -Proxy $currentProxy -RequestKey $requestKey
            $attemptState = 'ok'
            # 200 ≠ 存在：SourceForge 的 /download 对不存在的文件 302 回项目文件根目录（200 的 HTML
            # 错误页）。声明了 FinalUriMustContain 时核对最终地址仍包含该段，否则按不存在处理，
            # 让调用方继续尝试下一个候选（版本号从 URL 上取，重定向后的镜像地址仍带着它）
            if ($FinalUriMustContain) {
                $finalText = $head.FinalUri
                if ($finalText -and [Uri]::UnescapeDataString($finalText).IndexOf([Uri]::UnescapeDataString($FinalUriMustContain), [StringComparison]::OrdinalIgnoreCase) -lt 0) { $attemptState = 'missing' }
            }
        } catch {
            $statusCode = 0
            try { $response = $_.Exception.Response } catch { $response = $null }
            if ($null -ne $response) {
                try { $statusCode = [int]$response.StatusCode } catch { $statusCode = 0 }
            }
            if ($statusCode -eq 404 -or $statusCode -eq 410) {
                if (Test-WinstBotChallengeResponse -Response $response) {
                    # 404 只是校验页的状态码：文件在浏览器 / 下载引擎下是可以下的，不能判成不存在
                    $attemptState = 'blocked'
                } else {
                    $attemptState = 'missing'
                }
            } else {
                # 其它错误（网络故障、代理问题、服务器不支持 HEAD 等）：无法判断
                $attemptState = 'unknown'
            }
        }

        if ($attemptState -eq 'ok' -or $attemptState -eq 'missing') {
            $state = $attemptState
            break
        }
        # 人机校验随出口 IP / 客户端特征变化：直连被拦时换代理未必也被拦，所以不在这里收工
        if ($attemptState -eq 'blocked') {
            $state = 'blocked'
        }
    }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 校验安装包地址 {0} → {1}' -f $Uri, $state) -ForegroundColor DarkGray
    }

    if ($state -eq 'ok' -or $state -eq 'missing') {
        $at = if ($head) { $head.At } else { [DateTime]::Now }
        Set-WinstHttpCacheEntry -Key $cacheKey -Entry @{ At = $at; State = $state }
    }
    return @{ State = $state }
}
