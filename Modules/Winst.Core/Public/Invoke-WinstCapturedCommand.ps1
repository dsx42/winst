#Requires -Version 5.1

function Invoke-WinstCapturedCommand {
    <#
    .SYNOPSIS
        在「不接触当前控制台」的隐藏进程里执行命令并捕获输出。
    .DESCRIPTION
        为什么必须这样起进程：版本检测要运行目标软件自己，而「GUI + 控制台」混合型的程序（如 Rufus：
        `rufus.exe --help` 由它内置的控制台入口输出帮助）会把内容**直接写进控制台设备**，绕过 stdout 重定向。
        子进程与 winst 共用同一个控制台时，这段帮助文本就会打在 winst 的界面上，还会和随后的输入提示
        抢同一个控制台（例如 Rufus 装完后的 `Usage: rufus …` 与之后「请输入软件名称或关键字」里多出来的
        那一串内容都来自这里）。改用 CreateNoWindow（子进程**不继承当前控制台**）＋ 三路重定向后：
          · 输出只走管道，不会再打到 winst 的界面上；
          · stdin 立刻关闭（EOF），子进程读不到键盘、不会卡在等输入；
          · 它再启动的下级进程同样拿不到 winst 的控制台。
        代价：**只把版本写到标准输出 / 标准错误的程序才拿得到内容**——像 Rufus 那样直接写控制台的程序
        （没有控制台时什么都不输出）拿不到，检测判为未命中、台账回退本次安装的目标版本；这类条目应在
        软件源里改用不运行程序的检测方式（`fileVersion` / `markerFile` 等）。
    .OUTPUTS
        @{ Ok; TimedOut; ExitCode; Text; ErrText; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$Arguments = '',
        [int]$TimeoutMs = 10000,
        [switch]$NoTimeout
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
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $errTask = $p.StandardError.ReadToEndAsync()
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
        try { if ($outTask.Wait(2000)) { $result.Text = [string]$outTask.Result } } catch { $result.Text = '' }
        try { if ($errTask.Wait(2000)) { $result.ErrText = [string]$errTask.Result } } catch { $result.ErrText = '' }
    } finally {
        try { $p.Dispose() } catch { }
    }
    return $result
}
