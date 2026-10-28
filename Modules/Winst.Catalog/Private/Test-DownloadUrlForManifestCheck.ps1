#Requires -Version 5.1

function Test-DownloadUrlForManifestCheck {
    <#
    .SYNOPSIS
        校验解析出的下载地址是否真的可以下载，用于帮助发现软件源（清单）里的错误。
    .DESCRIPTION
        由 winst 自行拼出（模板）或从页面提取的地址都可能因清单写错而失效，故做一次 HEAD 探测。
        仅 404 / 410 判定为「地址不存在」并据此报错（提示检查清单）；网络失败、服务器不支持 HEAD
        等一律视为「无法判断」，只提示不报错，避免误伤。站点的人机校验（Cloudflare 挑战）单独成 'blocked'
        一态：它对非浏览器客户端回的就是 404，但文件是好的（JetBrains 的中国 CDN 即如此）。

        **默认带浏览器式请求头**：部分站点（如 filezilla-project.org）按客户端特征拒绝自动化请求，
        不带浏览器 UA 时返回 403 / 直接断开，判定退化为「无法判断（unknown）」。请求头在这里统一补上，
        避免同一个地址在不同来源下得出不同结论（不同结论还会因缓存键含请求头而并存）。
    .OUTPUTS
        'ok' / 'missing' / 'blocked' / 'unknown' / 'skipped'
    #>
    param(
        [hashtable]$Context,
        [string]$Url,
        [bool]$Skip = $false,
        [hashtable]$Headers = $null
    )

    if ($Skip) { return 'skipped' }
    if (-not $Url) { return 'unknown' }

    # 未显式给请求头时用浏览器式请求头（见上方说明）
    if (-not $Headers) { $Headers = Get-WinstBrowserHeaders }

    $probe = Get-WinstRemoteFileProbe -Uri $Url -Context $Context -Headers $Headers
    if ($probe.State -eq 'ok') { return 'ok' }
    if ($probe.State -eq 'missing') { return 'missing' }
    if ($probe.State -eq 'blocked') { return 'blocked' }
    return 'unknown'
}
