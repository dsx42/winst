#Requires -Version 5.1

function Send-WinstDevToolsMessage {
    <#
    .SYNOPSIS
        往 DevTools 连接（WebSocket）发一条 JSON 消息。
    #>
    param($Session, [hashtable]$Message)

    $json = $Message | ConvertTo-Json -Compress -Depth 8
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $segment = New-Object 'System.ArraySegment[byte]' -ArgumentList @(, $bytes)
    $task = $Session.Socket.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $Session.Token)
    if (-not $task.Wait(15000)) { throw '向无头浏览器发送 DevTools 命令超时' }
}
