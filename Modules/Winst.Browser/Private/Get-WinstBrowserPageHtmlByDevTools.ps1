#Requires -Version 5.1

function Get-WinstBrowserPageHtmlByDevTools {
    <#
    .SYNOPSIS
        用系统自带 Edge 的 DevTools 协议（CDP）取回页面 DOM —— `--dump-dom` 拿不到内容时的第二条路。
    .DESCRIPTION
        为什么要这条备用路径：`--dump-dom` 的 DOM 是**通过子进程的 stdout 管道**交给 winst 的，而 Edge 在
        **从提权进程启动**时会把浏览器进程降权重启（Chromium 的 de-elevation：用中完整性级别的进程重新拉起
        自己，再把原进程以 0 退出）——重定向的管道不跟着走，stdout / stderr 一个字都收不到，于是报
        「浏览器没有返回页面内容」，而且 profile 是正常建好的（20 MB 上下）、没有崩溃转储，光看现象很容易
        误判成「页面打不开」。winst 安装软件要提权，刷新时抓页面正好跑在这个提权进程里，所以这条路上
        失败是常态而不是偶发。

        CDP 不走 stdout：端口号从 profile 目录里的 `DevToolsActivePort` 读，DOM 用 `Runtime.evaluate` 取
        （`document.documentElement.outerHTML`）。降权重启不影响这两步——`source.click` 的点击取址一直
        就是这么工作的，提权进程里也正常。
    .OUTPUTS
        @{ Ok; Html; Error; Engine }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Url,
        [int]$TimeoutSec = 60
    )

    $result = @{ Ok = $false; Html = ''; Error = ''; Engine = '' }

    $ua = ''
    $headers = Get-WinstBrowserHeaders
    if ($headers -and $headers['User-Agent']) { $ua = [string]$headers['User-Agent'] }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $lastError = ''
    foreach ($proxyUrl in $attempts) {
        $session = $null
        try {
            $session = New-WinstDevToolsSession -ProxyUrl ([string]$proxyUrl) -UserAgent $ua
            if (-not $session.Ok) { $lastError = [string]$session.Error; continue }
            $result.Engine = [string]$session.Engine

            $null = Invoke-WinstDevToolsCommand -Session $session -Method 'Page.navigate' -Params @{ url = $Url }

            # 等 loadEventFired，最多 25 秒；页面长轮询时可能一直不给，超时也继续取 DOM
            $loadDeadline = [DateTime]::Now.AddSeconds(25)
            $hardDeadline = [DateTime]::Now.AddSeconds($TimeoutSec)
            if ($hardDeadline -lt $loadDeadline) { $loadDeadline = $hardDeadline }
            while (-not $session.LoadEventFired -and [DateTime]::Now -lt $loadDeadline) {
                Wait-WinstDevToolsMessages -Session $session -Milliseconds 100
            }
            # 页面脚本是在 DOMContentLoaded 之后才把内容拼上去的（下载页尤其如此），再给一点时间
            Wait-WinstDevToolsMessages -Session $session -Milliseconds 2000

            $html = [string](Get-WinstDevToolsValue -Session $session -Expression 'document.documentElement.outerHTML')
            if (-not $html) {
                $lastError = 'DevTools 取回的页面内容为空'
                continue
            }

            $result.Html = $html
            $result.Ok = $true
            $lastError = ''
            break
        } catch {
            $lastError = $_.Exception.Message
        } finally {
            Close-WinstDevToolsSession -Session $session
        }
    }

    if (-not $result.Ok) {
        $result.Error = $lastError
        if (@($attempts).Count -gt 1) { $result.Error = ('{0}（直连与代理均失败）' -f $lastError) }
    }
    return $result
}
