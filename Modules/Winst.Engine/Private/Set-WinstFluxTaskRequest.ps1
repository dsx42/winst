#Requires -Version 5.1

function Set-WinstFluxTaskRequest {
    param([hashtable]$Service, [string]$TaskId, [hashtable]$Headers, [string]$ProxyUrl)

    # FluxDown 的统一任务编辑器在 /rpc；读取修订号后再提交同一任务的新请求参数。
    $socket = New-Object Net.WebSockets.ClientWebSocket
    $timeout = New-Object Threading.CancellationTokenSource
    try {
        $timeout.CancelAfter(15000)
        $socket.Options.Proxy = $null
        $socket.Options.SetRequestHeader('Authorization', ('Bearer ' + ([Net.NetworkCredential]::new('', $Service.Token)).Password))
        $uri = [uri](($Service.Address -replace '^http','ws') + '/rpc')
        $null = $socket.ConnectAsync($uri, $timeout.Token).GetAwaiter().GetResult()
        $number = 0
        $revision = ''
        $buffer = New-Object byte[] 8192
        foreach ($method in @('system.hello', 'daemon.task.editInfo', 'daemon.task.edit')) {
            $number++
            switch ($method) {
                'system.hello' { $params = @{ clientName = 'winst'; clientVersion = (Get-WinstProductVersion); requestedRole = 'agent'; minProtocolVersion = 19; maxProtocolVersion = 29; capabilities = @() } }
                'daemon.task.editInfo' { $params = @{ taskId = $TaskId } }
                'daemon.task.edit' {
                    $extra = @{}
                    if ($Headers['Referer']) { $extra['Referer'] = [string]$Headers['Referer'] }
                    $params = @{ taskId = $TaskId; expectedRevision = $revision; cookies = [string]$Headers['Cookie']
                        headers = $extra; userAgent = [string]$Headers['User-Agent']; proxyUrl = $ProxyUrl }
                }
            }
            $frame = @{ jsonrpc = '2.0'; id = $number; method = $method; params = $params }
            $data = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $frame -Compress -Depth 6))
            $segment = New-Object 'ArraySegment[byte]' (,$data)
            $null = $socket.SendAsync($segment, 'Text', $true, $timeout.Token).GetAwaiter().GetResult()
            do {
                $stream = New-Object IO.MemoryStream
                try {
                    do {
                        $part = $socket.ReceiveAsync((New-Object 'ArraySegment[byte]' (,$buffer)), $timeout.Token).GetAwaiter().GetResult()
                        if ($part.MessageType -ne 'Text') { throw '任务编辑连接已关闭' }
                        $stream.Write($buffer, 0, $part.Count)
                    } until ($part.EndOfMessage)
                    $reply = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json -ErrorAction Stop
                } finally { $stream.Dispose() }
            } until ((Get-EntryString $reply 'id') -eq [string]$number)
            if ($reply.PSObject.Properties['error']) { throw ('任务编辑接口拒绝 {0}' -f $method) }
            if ($method -eq 'daemon.task.editInfo') {
                $revision = Get-EntryString $reply.result 'revision'
                if (-not $revision) { throw '任务编辑接口未返回修订号' }
            }
        }
    } finally {
        $socket.Dispose()
        $timeout.Dispose()
    }
}
