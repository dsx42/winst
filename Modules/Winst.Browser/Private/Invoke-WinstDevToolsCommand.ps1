#Requires -Version 5.1

function Invoke-WinstDevToolsCommand {
    <#
    .SYNOPSIS
        发一条 DevTools 命令并等到它的响应（期间收到的事件交给 Add-WinstDevToolsEvent）。
    .DESCRIPTION
        `-BrowserLevel` 用于浏览器级命令（如 Target.createTarget / Browser.setDownloadBehavior），
        这类命令不带 sessionId；其余命令发给当前页面会话（Target.attachToTarget 的 sessionId）。
    #>
    param($Session, [string]$Method, $Params = $null, [switch]$BrowserLevel, [int]$TimeoutMs = 20000)

    $id = [int]$Session.NextId
    $Session.NextId = $id + 1
    $message = @{ id = $id; method = $Method }
    if ($Params) { $message['params'] = $Params }
    if (-not $BrowserLevel) { $message['sessionId'] = [string]$Session.SessionId }
    Send-WinstDevToolsMessage -Session $Session -Message $message

    $deadline = [DateTime]::Now.AddMilliseconds($TimeoutMs)
    while ($true) {
        $remaining = [int]($deadline - [DateTime]::Now).TotalMilliseconds
        if ($remaining -le 0) { throw ('等待无头浏览器回应 {0} 超时' -f $Method) }

        $raw = Receive-WinstDevToolsMessage -Session $Session -TimeoutMs $remaining
        if (-not $raw) { continue }

        # 先用一次正则确认「这条是不是自己那条命令的响应」（响应一定以 {"id":N 开头），是才做 JSON 解析；
        # 其余消息当事件便宜地过一遍——把每条事件都 ConvertFrom-Json 会读不过来，反过来拖住渲染进程
        if ($raw -match ('^\s*\{\s*"id"\s*:\s*' + $id + '\s*[,}]')) {
            $object = $null
            try { $object = $raw | ConvertFrom-Json } catch { continue }
            if ($null -eq $object) { continue }

            $errorText = ''
            try { if ($null -ne $object.PSObject.Properties['error']) { $errorText = [string]$object.error.message } } catch { $errorText = '' }
            if ($errorText) { throw ('无头浏览器拒绝了 DevTools 命令 {0}：{1}' -f $Method, $errorText) }
            return $object
        }

        Add-WinstDevToolsEvent -Session $Session -Raw $raw
    }
}
