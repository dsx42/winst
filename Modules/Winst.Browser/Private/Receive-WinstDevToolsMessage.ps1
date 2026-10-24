#Requires -Version 5.1

function Receive-WinstDevToolsMessage {
    <#
    .SYNOPSIS
        从 DevTools 连接读一条完整消息；到点还没有消息返回空串。
    .DESCRIPTION
        ClientWebSocket 同时只允许一个未完成的 ReceiveAsync，所以「超时没等到」不能把接收任务丢掉：
        未完成的任务挂在会话上、下次接着等（否则下一次接收会直接报「已有未完成的接收」）。
        分片消息按 EndOfMessage 拼完整；连接出错时抛出，由调用方转成可读的失败原因。
    #>
    param($Session, [int]$TimeoutMs = 20000)

    if (-not $Session.Pending) {
        # 缓冲区与 ArraySegment 只建一次并复用：每条消息都 New-Object 会让读取速度掉到几毫秒一条，
        # 读得慢就会把浏览器的消息队列拖爆
        $buffer = New-Object byte[] 65536
        $Session.Pending = @{
            Buffer  = $buffer
            Segment = (New-Object 'System.ArraySegment[byte]' -ArgumentList @(, $buffer))
            Builder = (New-Object System.Text.StringBuilder 4096)
            Task    = $null
        }
    }
    $pending = $Session.Pending
    $deadline = [DateTime]::Now.AddMilliseconds($TimeoutMs)

    while ($true) {
        if ($null -eq $pending.Task) {
            $pending.Task = $Session.Socket.ReceiveAsync($pending.Segment, $Session.Token)
        }

        $remaining = [int]($deadline - [DateTime]::Now).TotalMilliseconds
        if ($remaining -lt 0) { $remaining = 0 }
        if (-not $pending.Task.Wait($remaining)) { return '' }

        $task = $pending.Task
        $pending.Task = $null
        $received = $null
        try {
            $received = $task.Result
        } catch {
            throw ('无头浏览器的 DevTools 连接出错：{0}' -f $_.Exception.Message)
        }

        $null = $pending.Builder.Append([System.Text.Encoding]::UTF8.GetString($pending.Buffer, 0, $received.Count))
        if ($received.EndOfMessage) {
            $text = $pending.Builder.ToString()
            $null = $pending.Builder.Clear()
            return $text
        }
    }
}
