#Requires -Version 5.1

function Stop-WinstRunningAppProcesses {
    <#
    .SYNOPSIS
        强制结束给定进程。
    .DESCRIPTION
        结束前按 PID 复核进程身份：快照最多有几秒延迟，这期间原进程退出、PID 被系统复用的话，
        直接 Stop-Process 会杀掉无关进程。复核时进程已经不在了算正常退出（Exited），不算失败：
        用户在提示期间手动关闭进程是常见操作，不能因此让安装 / 更新中止。
        结束时/失败后都让进程快照失效，否则调用方紧接着的重新检测仍读旧快照，会一直判定「仍在运行」。
    .OUTPUTS
        @{ Stopped; Exited; Failed = @( @{ Id; Name; Message } ) }
    #>
    param($Processes)

    $stopped = 0
    $exited = 0
    $failed = @()
    foreach ($proc in @($Processes)) {
        $procId = [int]$proc['Id']
        $expected = ([string]$proc['Name']).Trim()

        # 进程已经退出 / PID 已被系统复用：原进程不在了，直接跳过（不是失败）
        try { $live = Get-Process -Id $procId -ErrorAction Stop } catch {
            if ($_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) { $exited++; continue }
            $failed += @{ Id=$procId; Name=$expected; Message=('无法复核进程 {0}，请手动关闭：{1}' -f $procId, $_.Exception.Message) }
            continue
        }
        if ($null -eq $live) { $exited++; continue }
        if ($expected -and ((([string]$live.ProcessName) + '.exe') -ine $expected)) { $exited++; continue }

        try {
            $startedAt = Get-EntryValue -Entry $proc -Key 'StartedAt'
            $expectedPath = Get-EntryString -Entry $proc -Key 'Path'
            if ($null -eq $startedAt -or -not $expectedPath) { throw '无法确认进程创建时间或完整路径，请手动关闭程序' }
            # CIM 时间精度为微秒；与进程句柄上的创建时间按同一精度比较。
            $expectedTicks = ([datetime]$startedAt).ToUniversalTime().Ticks
            $liveTicks = $live.StartTime.ToUniversalTime().Ticks
            if ([long][Math]::Floor($expectedTicks / [decimal]10) -ne [long][Math]::Floor($liveTicks / [decimal]10)) { $exited++; continue }
            if (-not $live.Path) { throw '读不到进程完整路径，请手动关闭程序' }
            if ([string]$live.Path -ine $expectedPath) { $exited++; continue }
            Stop-Process -InputObject $live -Force -ErrorAction Stop
            $stopped++
        } catch {
            # 结束过程中进程自己退出也是正常结果：只有仍然存在才算失败
            if ($null -eq (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { $exited++; continue }
            $failed += @{
                Id      = $procId
                Name    = $expected
                Message = ('{0}（进程号 {1}）：{2}' -f $expected, $procId, $_.Exception.Message)
            }
        }
    }
    # 无论成败都让快照过期：调用方马上会重新检测，命中旧快照会误判「仍在运行」
    $null = Set-WinstState -Name WinstProcessCache -Value ($null)
    return @{ Stopped = $stopped; Exited = $exited; Failed = @($failed) }
}
