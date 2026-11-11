#Requires -Version 5.1

function New-WinstDevToolsSession {
    <#
    .SYNOPSIS
        起一个系统自带 Edge 的无头实例并连上 DevTools 协议（CDP），返回会话对象。
    .DESCRIPTION
        只用系统自带组件：Edge（操作系统组件）+ PS 5.1 自带的 .NET —— `System.Net.WebSockets.ClientWebSocket`
        做 WebSocket 客户端，`Invoke-WebRequest` 取 `/json/version` 里的 ws 地址。
        DevTools 端口用 `--remote-debugging-port=0`（浏览器自己挑，避免占端口冲突），端口号从用户数据目录里的
        `DevToolsActivePort` 文件首行读。浏览器进程要在整个点击流程里活着，所以拿进程句柄留着（这里不读退出码），
        结束时由 Close-WinstDevToolsSession 收尾。
        **起进程用 `[Diagnostics.Process]::Start(ProcessStartInfo)`，不用 `Start-Process`**：后者在环境里同时存在
        `http_proxy` 与 `HTTP_PROXY` 时会直接抛「已添加项。字典中的关键字:http_proxy」（Windows 环境变量不区分
        大小写，它复制环境时按区分大小写处理），浏览器根本起不来——装了 Clash / FlClash 之类工具的终端常带这种
        变量；ProcessStartInfo 原样继承环境，没有这个问题。
        **stdout / stderr 一律异步抽干**：不重定向的话，Edge 的 `DevTools listening on ws://…` 行与新 profile 首次
        运行的导入器扫描报错（QQBrowser user data path not found 等）会直接打进 winst 的控制台；而重定向后不读走，
        几 KB 的管道缓冲写满会让浏览器卡住。所以只保留文本（失败时截尾部拼进原因），不再落临时文件。
        默认把下载设为 `deny`：只让浏览器上报下载地址、不真下文件。
    .OUTPUTS
        @{ Ok; Error; Socket; Token; TokenSource; SessionId; TargetId; ProcessId; Process; StdoutTask; StderrTask; ProfileDir; Engine; Downloads; Requests }
    #>
    param(
        [string]$ProxyUrl = '',
        [string]$UserAgent = '',
        [int]$TimeoutSec = 40,
        [datetime]$Deadline = [datetime]::MaxValue
    )

    $result = @{
        Ok          = $false
        Error       = ''
        Socket      = $null
        Token       = $null
        TokenSource = $null
        Pending     = $null
        NextId      = 1
        SessionId   = ''
        TargetId    = ''
        ProcessId   = 0
        Process     = $null
        StdoutTask  = $null
        StderrTask  = $null
        ProfileDir  = ''
        Engine      = ''
        Downloads   = (New-Object System.Collections.ArrayList)
        Requests    = (New-Object System.Collections.ArrayList)
        LoadEventFired = $false
        FrameId     = ''
        Frames      = (New-WinstOrdinalDictionary)
        Deadline    = $Deadline
        CleanupError = ''
    }
    $localDeadline = [datetime]::UtcNow.AddSeconds($TimeoutSec)
    if ($localDeadline -lt $result.Deadline) { $result.Deadline = $localDeadline }

    $exe = Get-WinstSystemBrowserExe
    if (-not $exe) {
        $result.Error = '系统里没有找到 Microsoft Edge（Windows 自带的浏览器内核，无头抓取只用它）'
        Close-WinstDevToolsSession -Session $result
        return $result
    }
    $result.Engine = Split-Path -Leaf $exe

    # 用户代理与代理地址最终拼进浏览器命令行：含双引号就能提前闭合引号、追加任意开关
    # （代理地址来自 config.json / --proxy），拼接前显式拒绝
    foreach ($one in @($UserAgent, $ProxyUrl)) {
        if ($one -and -not (Test-WinstArgumentSafe -Value ([string]$one))) {
            $result.Error = '浏览器参数含有无法安全传给命令行的字符（双引号 / 控制字符）：请检查代理地址设置'
            return $result
        }
    }

    $profileDir = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-cdp-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $result.ProfileDir = $profileDir
    try { $null = New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop } catch { }

    # 浏览器的 stdout / stderr 必须有人读走（见上方说明），启动后立刻异步抽干；不落临时文件，
    # 失败时从 $cleanup 里把 stderr 尾部拼进错误原因
    $stdoutTask = $null
    $stderrTask = $null

    $argList = @(
        '--headless=new'
        '--disable-gpu'
        '--no-first-run'
        '--no-default-browser-check'
        '--disable-extensions'
        '--disable-features=UserAgentClientHint'
        '--disable-blink-features=AutomationControlled'
        '--window-size=1440,900'
        ('--user-agent=' + (Format-WinstCommandArgument -Value $UserAgent))
        ('--user-data-dir=' + (Format-WinstCommandArgument -Value $profileDir))
        '--remote-debugging-port=0'
        'about:blank'
    )
    if ($ProxyUrl) { $argList += ('--proxy-server=' + (Format-WinstCommandArgument -Value ([string]$ProxyUrl))) }

    $process = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = ($argList -join ' ')
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $process = [Diagnostics.Process]::Start($psi)
        $result.ProcessId = $process.Id
        $result.Process = $process
        # 立刻抽干两路输出：管道写满会把浏览器卡在半路
        $stdoutTask = [Winst.State]::CaptureAsync($process.StandardOutput, 65536, $true)
        $stderrTask = [Winst.State]::CaptureAsync($process.StandardError, 65536, $true)
        $result.StdoutTask = $stdoutTask
        $result.StderrTask = $stderrTask
    } catch {
        $result.Error = ('无法启动无头浏览器：{0}' -f $_.Exception.Message)
        Close-WinstDevToolsSession -Session $result
        if ($result.CleanupError) { $result.Error += ('；' + $result.CleanupError) }
        return $result
    }

    # 启动成功后的各失败出口统一收尾：杀掉整棵浏览器进程树 + 删 profile，不留残留进程。
    # 按 profile 目录匹配（拿到的 PID 可能只是先退出的那个引导进程）；
    # 顺手把浏览器自己的 stderr 尾部拼进错误原因——端口没就绪 / 连不上 DevTools 时，那才是线索
    $cleanup = {
        $tail = ''
        if ($stderrTask) {
            try { if ($stderrTask.IsCompleted) { $tail = [string]$stderrTask.Result } } catch { $tail = '' }
        }
        Close-WinstDevToolsSession -Session $result
        if ($result.CleanupError) { $result.Error += ('；' + $result.CleanupError) }
        if ($tail) {
            $tail = ($tail -replace '\s+', ' ').Trim()
            if ($tail.Length -gt 200) { $tail = $tail.Substring($tail.Length - 200) }
            if ($tail -and $result.Error) { $result.Error += ('（浏览器输出：{0}）' -f $tail) }
        }
    }

    $portFile = Join-WinstPath $profileDir 'DevToolsActivePort'
    $port = 0
    while ($port -le 0 -and [DateTime]::UtcNow -lt $result.Deadline) {
        if (Test-Path -LiteralPath $portFile -PathType Leaf) {
            try {
                $lines = @(Get-Content -LiteralPath $portFile -ErrorAction Stop)
                if ($lines.Count -ge 1) {
                    $first = ([string]$lines[0]).Trim()
                    if ($first -match '^\d+$') { $port = [int]$first }
                }
            } catch { $port = 0 }
        }
        if ($port -le 0) { Start-Sleep -Milliseconds (Get-WinstBrowserRemainingMs -Session $result -LimitMs 200 -Cleanup) }
    }
    if ($port -le 0) {
        $result.Error = ('无头浏览器没有在 {0} 秒内就绪（读不到 DevTools 端口）' -f $TimeoutSec)
        & $cleanup
        return $result
    }

    $wsUrl = ''
    $wsDeadline = [DateTime]::UtcNow.AddMilliseconds((Get-WinstBrowserRemainingMs -Session $result -LimitMs 15000 -Cleanup))
    while (-not $wsUrl -and [DateTime]::UtcNow -lt $wsDeadline) {
        try {
            $timeout = [Math]::Max(1, [int][Math]::Ceiling((Get-WinstBrowserRemainingMs -Session $result -LimitMs 3000) / 1000.0))
            $info = (Invoke-WebRequest -Uri ('http://127.0.0.1:{0}/json/version' -f $port) -UseBasicParsing -TimeoutSec $timeout).Content | ConvertFrom-Json
            $wsUrl = [string]$info.webSocketDebuggerUrl
        } catch { $wsUrl = '' }
        if (-not $wsUrl) { Start-Sleep -Milliseconds (Get-WinstBrowserRemainingMs -Session $result -LimitMs 250 -Cleanup) }
    }
    if (-not $wsUrl) {
        $result.Error = '拿不到无头浏览器的 DevTools 地址'
        & $cleanup
        return $result
    }

    $socket = New-Object System.Net.WebSockets.ClientWebSocket
    $source = New-Object System.Threading.CancellationTokenSource
    $result.Socket = $socket
    $result.TokenSource = $source
    $result.Token = $source.Token
    $source.CancelAfter((Get-WinstBrowserRemainingMs -Session $result -LimitMs ([int]::MaxValue) -Cleanup))

    $connected = $false
    try { $connected = $socket.ConnectAsync([Uri]$wsUrl, $source.Token).Wait((Get-WinstBrowserRemainingMs -Session $result -LimitMs 15000)) } catch { $connected = $false }
    if (-not $connected -or $socket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        $result.Error = '连接无头浏览器的 DevTools 失败'
        & $cleanup
        return $result
    }

    try {
        $created = Invoke-WinstDevToolsCommand -Session $result -Method 'Target.createTarget' -Params @{ url = 'about:blank' } -BrowserLevel
        $result.TargetId = [string]$created.result.targetId
        $attached = Invoke-WinstDevToolsCommand -Session $result -Method 'Target.attachToTarget' -Params @{ targetId = $result.TargetId; flatten = $true } -BrowserLevel
        $result.SessionId = [string]$attached.result.sessionId
        $null = Invoke-WinstDevToolsCommand -Session $result -Method 'Page.enable'
        $null = Invoke-WinstDevToolsCommand -Session $result -Method 'Network.enable'
        $null = Invoke-WinstDevToolsCommand -Session $result -Method 'Runtime.enable'
        $tree = Invoke-WinstDevToolsCommand -Session $result -Method 'Page.getFrameTree'
        $result.FrameId = [string]$tree.result.frameTree.frame.id
        if (-not $result.FrameId) { throw '读不到浏览器主 frame 身份' }
        $result.Frames[$result.FrameId] = $true
        # 只取地址、不真下文件：deny 下浏览器照样上报 downloadWillBegin
        $null = Invoke-WinstDevToolsCommand -Session $result -Method 'Browser.setDownloadBehavior' -Params @{ behavior = 'deny'; eventsEnabled = $true } -BrowserLevel
    } catch {
        $result.Error = ('初始化无头浏览器会话失败：{0}' -f $_.Exception.Message)
        & $cleanup
        return $result
    }

    $result.Ok = $true
    return $result
}
