#Requires -Version 5.1

function Start-WinstDevToolsNavigation {
    <#
    .SYNOPSIS
        导航到主 frame 并拒绝错误页面。
    #>
    param($Session, [string]$Url)

    $Session.LoadEventFired = $false
    $response = Invoke-WinstDevToolsCommand -Session $Session -Method 'Page.navigate' -Params @{ url=$Url; frameId=$Session.FrameId }
    $navigation = Get-EntryValue $response 'result'
    $errorText = Get-EntryString $navigation 'errorText'
    if ($errorText) { throw ('浏览器导航失败：{0}' -f $errorText) }
    if ((Get-EntryString $navigation 'frameId') -cne $Session.FrameId) { throw '浏览器导航响应不属于目标主 frame' }
}
