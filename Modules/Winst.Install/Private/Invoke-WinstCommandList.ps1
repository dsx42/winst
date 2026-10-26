#Requires -Version 5.1

function Invoke-WinstCommandList {
    <#
    .SYNOPSIS
        执行一组清单命令（postInstall / uninstall.commands 共用）：[{ exe, args, timeoutSec, requireAdmin }]。
    .DESCRIPTION
        - exe / args 都支持 {installDir} / {installRoot} 占位符与 %VAR% 环境变量引用（如 MPC-VR 用
          %SystemRoot%\System32\regsvr32.exe 按 "{installDir}\MpcVideoRenderer64.ax" 注册 / 注销滤镜）；
          两处都在启动前展开——args 不展开占位符会让 regsvr32 收到字面量路径，LoadLibrary 失败（退出码 3）；
        - requireAdmin: true —— 这一步必须提权时先检查当前进程是不是管理员，不是就给出明确提示、不启动命令
          （如 MPC-VR 用 regsvr32 注册 / 注销 DirectShow 滤镜）；
        - 起进程用 ProcessStartInfo（等价于 `-NoNewWindow`）：子进程**继承当前控制台**，命令自己的输出
          （pip 的进度 / regsvr32 的报错之类）照常显示在界面上。退出码必须能可靠读到——
          `Start-Process -PassThru` 不带 `-Wait` 时再手动 `WaitForExit()`，`$p.ExitCode` 恒为 `$null`，
          于是 `$null -ne 0` 恒真、退出码 0 的命令被误判成失败（消息里还会渲染出空的「退出码 」）；
          详。确实拿不到退出码时按成功处理（没有任何证据说明它失败），只打一行提示。
        $Label 只用于拼错误消息（「安装后」/「卸载」），便于用户看出是哪一步失败。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param(
        [Parameter(Mandatory = $true)]$Commands,
        [string]$Label = '命令',
        [string]$InstallDir = '',
        [string]$InstallRoot = ''
    )

    foreach ($command in @($Commands)) {
        # 先展开环境变量、再替换占位符：反过来的话，{installDir} 等占位符展开出的路径里若含 %VAR%
        # 会被再解释一次（二次展开），安装目录名里的 % 会变成意外内容
        $exeRaw = [Environment]::ExpandEnvironmentVariables((Get-EntryString -Entry $command -Key 'exe'))
        $exeText = Expand-PlanPlaceholders -Value $exeRaw -InstallDir $InstallDir -InstallRoot $InstallRoot
        if (-not $exeText) { continue }
        if (-not (Test-WinstArgumentSafe -Value $exeText)) {
            return @{ Ok = $false; Error = ('{0}要执行的程序路径含双引号或控制字符，已拒绝执行：{1}' -f $Label, $exeText) }
        }
        $exePath = $exeText
        if (-not [IO.Path]::IsPathRooted($exePath)) { $exePath = Join-WinstPath $InstallDir $exePath }
        if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
            return @{ Ok = $false; Error = ('{0}要执行的程序不存在：{1}' -f $Label, $exePath) }
        }
        $argsRaw = [Environment]::ExpandEnvironmentVariables((Get-EntryString -Entry $command -Key 'args'))
        $argsText = Expand-PlanPlaceholders -Value $argsRaw -InstallDir $InstallDir -InstallRoot $InstallRoot
        # 参数是清单声明的命令行片段，允许带引号；但不允许出现换行等控制字符
        if ($argsText -match '[\x00-\x1F]') {
            return @{ Ok = $false; Error = ('{0}的参数含有换行等控制字符，已拒绝执行：{1}' -f $Label, $exePath) }
        }
        $timeoutSec = Get-EntryInt -Entry $command -Key 'timeoutSec' -Default 600
        if ($timeoutSec -le 0) { $timeoutSec = 600 }

        # requireAdmin：必须先提权的命令（regsvr32 注册 / 注销滤镜等）在这里前置检查，别让用户拿到一个看不懂的退出码
        if ((Get-EntryBool -Entry $command -Key 'requireAdmin') -and -not (Test-WinstIsAdministrator)) {
            return @{ Ok = $false; Error = ('{0}需要管理员权限：{1} {2}；请以管理员身份运行 winst 后重试' -f $Label, $exePath, $argsText).TrimEnd() }
        }

        # 起进程：UseShellExecute = false + 不设 CreateNoWindow = 子进程继承当前控制台，
        # 命令的输出要照常显示在界面上。
        # 必须用 ProcessStartInfo 直接读取退出码：`Start-Process -PassThru` 的 ExitCode 可能为 $null，
        # 会让退出码 0 的命令被误判为失败
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exePath
        if ($argsText) { $psi.Arguments = $argsText }
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $false
        try {
            $p = [Diagnostics.Process]::Start($psi)
        } catch {
            return @{ Ok = $false; Error = ('执行{0}失败：{1}' -f $Label, $_.Exception.Message) }
        }

        try {
            if (-not $p.WaitForExit($timeoutSec * 1000)) {
                # 只 Kill 主进程会留下子进程占住安装目录（与 L14394 的超时处理保持同一口径：按进程树结束）
                try { $null = & taskkill.exe /PID $p.Id /T /F 2>&1 } catch { }
                try { $p.Kill() } catch { }
                try { $null = $p.WaitForExit(5000) } catch { }
                return @{ Ok = $false; Error = ('{0}超时（{1} 秒）：{2} {3}' -f $Label, $timeoutSec, $exePath, $argsText) }
            }
            $exitCode = $null
            try { $exitCode = $p.ExitCode } catch { $exitCode = $null }
            if ($null -eq $exitCode) {
                # 拿不到退出码就没有任何证据说明它失败：只提示一行，按成功继续（绝不误报）
                Write-Host ('    提示: 无法读取{0}的退出码，按成功处理' -f $Label) -ForegroundColor DarkYellow
            } elseif ($exitCode -ne 0) {
                return @{ Ok = $false; Error = ('{0}失败（退出码 {1}）：{2} {3}' -f $Label, $exitCode, $exePath, $argsText) }
            }
        } finally {
            try { $p.Dispose() } catch { }
        }
    }
    # 清单命令常写注册表 / 环境变量（regsvr32、安装器自带参数等）：让系统快照失效，后续检测读到真实状态
    Reset-WinstSystemCache
    return @{ Ok = $true; Error = '' }
}
