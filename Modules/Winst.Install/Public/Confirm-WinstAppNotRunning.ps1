#Requires -Version 5.1

function Confirm-WinstAppNotRunning {
    <#
    .SYNOPSIS
        安装 / 覆盖 / 卸载前确认目标软件没有在运行：强杀 / 已手动关闭 / 取消。
    .DESCRIPTION
        正在运行的软件会锁住安装目录里的文件，导致解压、覆盖或删除失败。检测到运行中的进程时：
        `k` = 结束这些进程后继续；`c` = 用户已手动关闭，重新检测；其它输入 = 取消。
        -Action 传动作名词（安装 / 卸载），只影响提示文案；默认「安装」。
        非交互（`--yes` / 输入被重定向）时不擅自杀进程：`--kill` 才结束进程，否则报错并给出指引。
    .OUTPUTS
        @{ Ok; Cancelled; Error; Killed; Running }
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$InstallDir = '',
        [string[]]$ExtraDirs = @(),
        [switch]$Kill,
        [switch]$NonInteractive,
        [switch]$Quiet,
        [string]$Action = '安装'
    )

    $result = @{ Ok = $true; Cancelled = $false; Error = ''; Killed = 0; Running = @() }

    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = Get-EntryString -Entry $Plan -Key 'id' }

    $attempt = 0
    while ($true) {
        $attempt++
        $running = @(Get-WinstRunningAppProcess -Context $Context -Plan $Plan -InstallDir $InstallDir -ExtraDirs $ExtraDirs)
        if ($running.Count -eq 0) { return $result }
        $result.Running = $running

        if ($Kill) {
            # `--kill` 是「不询问就结束」的批量开关：只杀路径确认位于该软件目录的进程。
            # 仅按进程名兜底匹配的（路径不可见 / 别处的同名程序）不自动杀，报错让用户手动处理，
            # 否则 `processes: ["java"]` 这类声明会把用户机器上所有 JVM 一起杀掉。
            $split = Split-WinstKillableProcesses -Processes $running
            $stop = Stop-WinstRunningAppProcesses -Processes $split.Killable
            $result.Killed += [int]$stop.Stopped
            if ($stop.Failed.Count -gt 0) {
                $result.Ok = $false
                $result.Error = ('无法结束 {0} 的进程：{1}' -f $displayName, ($stop.Failed -join '；'))
                return $result
            }
            if (@($split.Blocked).Count -gt 0) {
                $blockedNames = @($split.Blocked | ForEach-Object { ('{0}（进程号 {1}）' -f [string]$_['Name'], [int]$_['Id']) })
                $result.Ok = $false
                $result.Error = ('{0} 仍有无法确认归属的进程：{1}。为避免误杀同名程序，winst 不会自动结束它们；请手动关闭后重试。' -f $displayName, ($blockedNames -join '、'))
                return $result
            }
            if ($attempt -ge 5) {
                $result.Ok = $false
                $result.Error = ('{0} 仍在运行，多次尝试结束进程仍未成功，{1}已中止。' -f $displayName, $Action)
                return $result
            }
            if (-not $Quiet) { Write-Host ('  已结束 {0} 个进程，继续{1} …' -f $stop.Stopped, $Action) -ForegroundColor Gray }
            Start-Sleep -Milliseconds 800
            continue
        }

        if ($NonInteractive -or $Quiet) {
            # -Quiet 连提示都不输出，此时再 Read-Host 就是「黑屏等输入」：按非交互处理并给出 --kill 指引
            $names = @($running | ForEach-Object { [string]$_.Name })
            $result.Ok = $false
            $result.Error = ('{0} 正在运行（{1}），文件被占用会导致{2}失败。请先关闭它后重试；如需 winst 自动结束这些进程，请加 --kill。' -f $displayName, ($names -join '、'), $Action)
            return $result
        }

        if (-not $Quiet) {
            Write-Host ''
            Write-Host ('  {0} 正在运行，文件被占用会导致{1}失败：' -f $displayName, $Action) -ForegroundColor Yellow
            foreach ($proc in $running) {
                $pathText = [string]$proc['Path']
                if (-not $pathText) { $pathText = '（路径不可见）' }
                Write-Host ('    - {0}（进程号 {1}）  {2}' -f [string]$proc['Name'], [int]$proc['Id'], $pathText) -ForegroundColor Gray
            }
            Write-Host ''
            Write-Host ('  k) 结束这些进程，然后继续{0}' -f $Action) -ForegroundColor White
            Write-Host '  c) 我已经手动关闭了（重新检测）' -ForegroundColor White
            Write-Host ('  回车 / 其它任意输入 = 取消{0}' -f $Action) -ForegroundColor DarkGray
        }

        $answer = ''
        try { $answer = [string](Read-Host '  请选择') } catch { $answer = '' }
        $choice = ''
        if ($null -ne $answer) { $choice = $answer.Trim().ToLowerInvariant() }

        if ($choice -eq 'k') {
            # 交互确认也只自动结束「路径确认」的进程；按名字兜底的仍要求用户自己关
            $split = Split-WinstKillableProcesses -Processes $running
            $stop = Stop-WinstRunningAppProcesses -Processes $split.Killable
            $result.Killed += [int]$stop.Stopped
            if (-not $Quiet) {
                if ($stop.Failed.Count -gt 0) {
                    Write-Host ('  部分进程结束失败：{0}' -f ($stop.Failed -join '；')) -ForegroundColor Yellow
                } else {
                    Write-Host ('  已结束 {0} 个进程。' -f $stop.Stopped) -ForegroundColor Gray
                }
            }
            if (@($split.Blocked).Count -gt 0) {
                $blockedNames = @($split.Blocked | ForEach-Object { ('{0}（进程号 {1}）' -f [string]$_['Name'], [int]$_['Id']) })
                $result.Ok = $false
                $result.Error = ('无法确认以下进程属于 {0}，为避免误杀同名程序未自动结束：{1}。请手动关闭后重试。' -f $displayName, ($blockedNames -join '、'))
                return $result
            }
            if ($attempt -ge 5) {
                $result.Ok = $false
                $result.Error = ('{0} 仍在运行，多次尝试结束进程仍未成功，{1}已中止。' -f $displayName, $Action)
                return $result
            }
            Start-Sleep -Milliseconds 800
            continue
        }

        if ($choice -eq 'c') {
            if ($attempt -ge 5) {
                $result.Ok = $false
                $result.Error = ('{0} 仍在运行，{1}已中止。请关闭它后重试。' -f $displayName, $Action)
                return $result
            }
            Start-Sleep -Milliseconds 500
            continue
        }

        $result.Ok = $false
        $result.Cancelled = $true
        return $result
    }
}
