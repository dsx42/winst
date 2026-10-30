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
            Decoder = [System.Text.Encoding]::UTF8.GetDecoder()
            Chars   = (New-Object char[] ([System.Text.Encoding]::UTF8.GetMaxCharCount(65536)))
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

        # UTF-8 字符可能跨分片；Decoder 与待接收任务一起保留到消息结束（包括超时重入）。
        $charCount = $pending.Decoder.GetChars($pending.Buffer, 0, $received.Count, $pending.Chars, 0, [bool]$received.EndOfMessage)
        $null = $pending.Builder.Append($pending.Chars, 0, $charCount)
        if ($received.EndOfMessage) {
            $text = $pending.Builder.ToString()
            $null = $pending.Builder.Clear()
            $pending.Decoder.Reset()
            return $text
        }
    }
}
