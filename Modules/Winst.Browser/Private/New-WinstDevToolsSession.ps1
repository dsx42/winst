#Requires -Version 5.1

function New-WinstDevToolsSession {
    <#
    .SYNOPSIS
        起一个系统自带 Edge 的无头实例并连上 DevTools 协议（CDP），返回会话对象。
    .DESCRIPTION
        只用系统自带组件：Edge（操作系统组件）+ PS 5.1 自带的 .NET —— `System.Net.WebSockets.ClientWebSocket`
        做 WebSocket 客户端，`Invoke-WebRequest` 取 `/json/version` 里的 ws 地址。
        DevTools 端口用 `--remote-debugging-port=0`（浏览器自己挑，避免占端口冲突），端口号从用户数据目录里的
        `DevToolsActivePort` 文件首行读。浏览器进程要在整个点击流程里活着，所以用 `Start-Process -PassThru`
        拿进程句柄（这里不读退出码），结束时由 Close-WinstDevToolsSession 收尾。
        **stdout / stderr 一律重定向到 profile 目录内的临时文件**：不重定向的话，Edge 的
        `DevTools listening on ws://…` 行与新 profile 首次运行的导入器扫描报错（QQBrowser user data path
        not found 等）会直接打进 winst 的控制台。日志文件随 ProfileDir 一并清理。
        默认把下载设为 `deny`：只让浏览器上报下载地址、不真下文件。
    .OUTPUTS
        @{ Ok; Error; Socket; Token; TokenSource; SessionId; TargetId; ProcessId; ProfileDir; Engine; Downloads; Requests }
    #>
    param(
        [string]$ProxyUrl = '',
        [string]$UserAgent = '',
        [int]$TimeoutSec = 40
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
        ProfileDir  = ''
        Engine      = ''
        Downloads   = (New-Object System.Collections.ArrayList)
        Requests    = (New-Object System.Collections.ArrayList)
        LoadEventFired = $false
    }

    $exe = Get-WinstSystemBrowserExe
    if (-not $exe) {
        $result.Error = '系统里没有找到 Microsoft Edge（Windows 自带的浏览器内核，无头抓取只用它）'
        return $result
    }
    $result.Engine = Split-Path -Leaf $exe

    $profileDir = Join-Path ([IO.Path]::GetTempPath()) ('winst-cdp-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $result.ProfileDir = $profileDir
    try { $null = New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop } catch { }

    # 浏览器的 stdout/stderr 落进 profile 目录内的临时文件（DevTools listening、导入器扫描报错等噪音
    # 不能进 winst 控制台）；文件随 ProfileDir 一并清理，失败路径先杀进程树再删目录（见 $cleanup）。
    $stdoutFile = Join-Path $profileDir 'browser-stdout.log'
    $stderrFile = Join-Path $profileDir 'browser-stderr.log'

    $argList = @(
        '--headless=new'
        '--disable-gpu'
        '--no-first-run'
        '--no-default-browser-check'
        '--disable-extensions'
        '--disable-features=UserAgentClientHint'
        '--disable-blink-features=AutomationControlled'
        '--window-size=1440,900'
        ('--user-agent="{0}"' -f $UserAgent)
        ('--user-data-dir="{0}"' -f $profileDir)
        '--remote-debugging-port=0'
        'about:blank'
    )
    if ($ProxyUrl) { $argList += ('--proxy-server="{0}"' -f $ProxyUrl) }

    try {
        $process = Start-Process -FilePath $exe -ArgumentList $argList -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $result.ProcessId = $process.Id
    } catch {
        $result.Error = ('无法启动无头浏览器：{0}' -f $_.Exception.Message)
        return $result
    }

    # 启动成功后的各失败出口统一收尾：杀掉整棵浏览器进程树 + 删 profile（含重定向日志），不留残留进程
    $cleanup = {
        if ($result.ProcessId) { try { $null = & taskkill.exe /PID $result.ProcessId /T /F 2>&1 } catch { } }
        if ($profileDir -and (Test-Path -LiteralPath $profileDir)) {
            Clear-WinstInstallDir -Dir $profileDir
        }
    }

    $portFile = Join-Path $profileDir 'DevToolsActivePort'
    $port = 0
    $portDeadline = [DateTime]::Now.AddSeconds($TimeoutSec)
    while ($port -le 0 -and [DateTime]::Now -lt $portDeadline) {
        if (Test-Path -LiteralPath $portFile -PathType Leaf) {
            try {
                $lines = @(Get-Content -LiteralPath $portFile -ErrorAction Stop)
                if ($lines.Count -ge 1) {
                    $first = ([string]$lines[0]).Trim()
                    if ($first -match '^\d+$') { $port = [int]$first }
                }
            } catch { $port = 0 }
        }
        if ($port -le 0) { Start-Sleep -Milliseconds 200 }
    }
    if ($port -le 0) {
        $result.Error = ('无头浏览器没有在 {0} 秒内就绪（读不到 DevTools 端口）' -f $TimeoutSec)
        & $cleanup
        return $result
    }

    $wsUrl = ''
    $wsDeadline = [DateTime]::Now.AddSeconds(15)
    while (-not $wsUrl -and [DateTime]::Now -lt $wsDeadline) {
        try {
            $info = (Invoke-WebRequest -Uri ('http://127.0.0.1:{0}/json/version' -f $port) -UseBasicParsing -TimeoutSec 3).Content | ConvertFrom-Json
            $wsUrl = [string]$info.webSocketDebuggerUrl
        } catch { $wsUrl = '' }
        if (-not $wsUrl) { Start-Sleep -Milliseconds 250 }
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

    $connected = $false
    try { $connected = $socket.ConnectAsync([Uri]$wsUrl, $source.Token).Wait(15000) } catch { $connected = $false }
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
        # 只取地址、不真下文件：deny 下浏览器照样上报 downloadWillBegin
        try {
            $null = Invoke-WinstDevToolsCommand -Session $result -Method 'Browser.setDownloadBehavior' -Params @{ behavior = 'deny'; eventsEnabled = $true } -BrowserLevel
        } catch { }
    } catch {
        $result.Error = ('初始化无头浏览器会话失败：{0}' -f $_.Exception.Message)
        & $cleanup
        return $result
    }

    $result.Ok = $true
    return $result
}
