#Requires -Version 5.1

function Add-WinstDevToolsEvent {
    <#
    .SYNOPSIS
        按 CDP 方法、页面会话和 frame 归属接收下载、请求与加载事件。
    #>
    param($Session, [string]$Raw)

    if (-not $Raw) { return }
    try { $event = ConvertFrom-Json -InputObject $Raw -ErrorAction Stop } catch { return }
    $method = Get-EntryString $event 'method'
    $params = Get-EntryValue $event 'params'
    if (-not $params) { return }
    $sessionId = Get-EntryString $event 'sessionId'
    if ($method -ceq 'Browser.downloadWillBegin') {
        $frameId = Get-EntryString $params 'frameId'
        if ($frameId -and $Session.Frames.Contains($frameId)) {
            $url = Get-EntryString $params 'url'
            if ($url) { $null = $Session.Downloads.Add($url) }
        }
        return
    }
    if (-not $sessionId -or $sessionId -cne $Session.SessionId) { return }
    switch -CaseSensitive ($method) {
        'Page.frameAttached' {
            $parentId = Get-EntryString $params 'parentFrameId'
            if ($Session.Frames.Contains($parentId)) { $Session.Frames[(Get-EntryString $params 'frameId')] = $true }
        }
        'Page.frameDetached' { $Session.Frames.Remove((Get-EntryString $params 'frameId')) }
        'Page.frameNavigated' {
            $frame = Get-EntryValue $params 'frame'
            $frameId = Get-EntryString $frame 'id'
            $parentId = Get-EntryString $frame 'parentId'
            if ($frameId -ceq $Session.FrameId -or ($parentId -and $Session.Frames.Contains($parentId))) { $Session.Frames[$frameId] = $true }
        }
        'Page.downloadWillBegin' {
            if ($Session.Frames.Contains((Get-EntryString $params 'frameId'))) {
                $url = Get-EntryString $params 'url'
                if ($url) { $null = $Session.Downloads.Add($url) }
            }
        }
        'Network.requestWillBeSent' {
            $request = Get-EntryValue $params 'request'
            $url = Get-EntryString $request 'url'
            if ($url -match '(?i)\.(exe|msi|cab|zip|7z|rar|dmg|deb|rpm|pkg|msix|appx|jar|apk)(\?|$)') { $null = $Session.Requests.Add($url) }
        }
        'Page.loadEventFired' { $Session.LoadEventFired = $true }
    }
}
