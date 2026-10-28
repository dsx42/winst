#Requires -Version 5.1

function Test-WinstBotChallengeResponse {
    <#
    .SYNOPSIS
        判断一个 HTTP 错误响应是「站点的人机校验页」，而不是真实的 404 / 403。
    .DESCRIPTION
        为什么需要它：JetBrains 的中国 CDN（download-cdn.clf.jetbrains.com.cn，Cloudflare 托管）对
        .NET / PowerShell 这类非浏览器客户端一律返回 **404 + `Cf-Mitigated: challenge`**——状态码是 404，
        内容却是「先过人机校验再谈」的挑战页，而文件本身好得很（同一条地址用浏览器或下载引擎都能下）。
        只看状态码会把「被拦住」判成「地址不存在」，进而在刷新阶段把这个软件判为解析失败、提示清单地址
        失效，可清单其实是对的。

        只认 Cloudflare 的显式标记（`Cf-Mitigated: challenge`）：其它站点回来的 403 / 404 分不清「被拦」
        还是「真没有」，仍按原口径处理。
    .OUTPUTS
        [bool]
    #>
    param($Response)

    if ($null -eq $Response) { return $false }
    $headers = $null
    try { $headers = $Response.Headers } catch { return $false }
    if ($null -eq $headers) { return $false }

    $mitigated = ''
    try { $mitigated = [string]$headers['Cf-Mitigated'] } catch { $mitigated = '' }
    if ($mitigated -and $mitigated.Trim() -eq 'challenge') { return $true }
    return $false
}
