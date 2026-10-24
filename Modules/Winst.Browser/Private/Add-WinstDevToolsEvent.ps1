#Requires -Version 5.1

function Add-WinstDevToolsEvent {
    <#
    .SYNOPSIS
        把 DevTools 事件里我们关心的内容收进会话对象（下载地址、像安装包的请求地址、页面是否加载完）。
    .DESCRIPTION
        取「点击后生成的下载地址」有两条渠道，按可靠性排序：
        ① `Browser.downloadWillBegin` / `Page.downloadWillBegin`：浏览器真发起了下载，`params.url` 就是下载地址（准）；
        ② `Network.requestWillBeSent` 里扩展名像安装包的请求：兜底线索，零命中报错时列出来给用户排查。
        入参是消息原文而不是解析后的对象：先用一次子串查找把无关事件筛掉，避免每条事件都做 JSON 解析。
    #>
    param($Session, [string]$Raw)

    if (-not $Raw) { return }

    if ($Raw.IndexOf('downloadWillBegin', [StringComparison]::Ordinal) -ge 0) {
        $url = Get-WinstDevToolsStringField -Text $Raw -Name 'url'
        if ($url) { $null = $Session.Downloads.Add($url) }
        return
    }

    if ($Raw.IndexOf('"method":"Network.requestWillBeSent"', [StringComparison]::Ordinal) -ge 0) {
        $url = Get-WinstDevToolsStringField -Text $Raw -Name 'url'
        if ($url -and ($url -match '(?i)\.(exe|msi|cab|zip|7z|rar|dmg|deb|rpm|pkg|msix|appx|jar|apk)(\?|$)')) {
            $null = $Session.Requests.Add($url)
        }
        return
    }

    if ($Raw.IndexOf('loadEventFired', [StringComparison]::Ordinal) -ge 0) { $Session.LoadEventFired = $true }
}
