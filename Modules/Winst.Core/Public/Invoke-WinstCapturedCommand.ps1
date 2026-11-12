#Requires -Version 5.1

function Invoke-WinstCapturedCommand {
    <#
    .SYNOPSIS
        在「不接触当前控制台」的隐藏进程里执行命令并捕获输出。
    .DESCRIPTION
        CreateNoWindow 隔离控制台；立即关闭 stdin，两路异步排空。
        标准输出默认保留完整文本，超过 MaxOutputChars 明确失败；TailOutput 只保留诊断尾部。
        标准错误保留有界尾部。NoTimeout 用于下载等需要持续运行的任务。
    .OUTPUTS
        @{ Ok; TimedOut; ExitCode; Text; ErrText; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$Arguments = '',
        [int]$TimeoutMs = 10000,
        [switch]$NoTimeout,
        [ValidateRange(1, 2147483647)][int]$MaxOutputChars = 16777216,
        [switch]$TailOutput
    )

    $result = @{ Ok = $false; TimedOut = $false; ExitCode = -1; Text = ''; ErrText = ''; Error = '' }
    # -NoTimeout：不限时等待（下载这类可能跑很久的动作用它）；否则 TimeoutMs <= 0 仍按默认 10 秒处理（版本检测的既有行为）
    if (-not $NoTimeout -and $TimeoutMs -le 0) { $TimeoutMs = 10000 }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    # 这一行就是「不与当前控制台共享」的关键（见上方说明）
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # 版本号都是 ASCII；中文按系统代码页输出时解出来只是乱码，不影响版本识别
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8

    $p = $null
    try {
        $p = [Diagnostics.Process]::Start($psi)
    } catch {
        $result.Error = ('执行命令失败: {0}' -f $_.Exception.Message)
        return $result
    }

    try {
        # 两路输出都异步读走（任一路管道写满都会让子进程卡住），随后立刻关掉 stdin 给它一个 EOF
        $outTask = [Winst.State]::CaptureAsync($p.StandardOutput, $MaxOutputChars, [bool]$TailOutput)
        $errTask = [Winst.State]::CaptureAsync($p.StandardError, 65536, $true)
        try { $p.StandardInput.Close() } catch { }

        $finished = $false
        if ($NoTimeout) {
            $p.WaitForExit()
            $finished = $true
        } else {
            $finished = $p.WaitForExit($TimeoutMs)
        }
        if (-not $finished) {
            $result.TimedOut = $true
            # 连同它启动的下级进程一起结束：残留进程会继续写控制台、抢键盘（Rufus 的控制台入口正是这种）
            try { $null = & taskkill.exe /PID $p.Id /T /F 2>&1 } catch { }
            try { $p.Kill() } catch { }
            try { $null = $p.WaitForExit(3000) } catch { }
            $result.Error = ('命令超时（{0} 秒）: {1} {2}' -f [int]($TimeoutMs / 1000), $FilePath, $Arguments)
            return $result
        }

        $result.ExitCode = $p.ExitCode
        $result.Ok = $true
        try {
            if (-not $outTask.Wait(2000)) { throw '命令结束后输出流未关闭' }
            $result.Text = [string]$outTask.Result
        } catch {
            $result.Ok = $false
            $result.Error = ('读取命令输出失败：{0}' -f $_.Exception.GetBaseException().Message)
        }
        try { if ($errTask.Wait(2000)) { $result.ErrText = [string]$errTask.Result } } catch { $result.ErrText = '' }
    } finally {
        try { $p.Dispose() } catch { }
    }
    return $result
}
