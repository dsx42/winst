#Requires -Version 5.1

function Stop-WinstRunningAppProcesses {
    <#
    .SYNOPSIS
        强制结束给定进程。
    .DESCRIPTION
        结束前按 PID 复核进程身份：快照最多有几秒延迟，这期间原进程退出、PID 被系统复用的话，
        直接 Stop-Process 会杀掉无关进程。结束时/失败后都让进程快照失效，否则调用方紧接着的
        重新检测仍读旧快照，会一直判定「仍在运行」。
    .OUTPUTS
        @{ Stopped; Failed = @( 说明文本 ) }
    #>
    param($Processes)

    $stopped = 0
    $failed = @()
    foreach ($proc in @($Processes)) {
        $procId = [int]$proc['Id']
        try {
            $live = Get-Process -Id $procId -ErrorAction Stop
            $expected = ([string]$proc['Name']).Trim()
            if ($expected) {
                $actual = ([string]$live.ProcessName) + '.exe'
                if ($actual -ine $expected) {
                    $failed += ('{0}（进程号 {1}）已不是原来的进程，已跳过' -f $expected, $procId)
                    continue
                }
            }
            Stop-Process -Id $procId -Force -ErrorAction Stop
            $stopped++
        } catch {
            $failed += ('{0}（进程号 {1}）：{2}' -f [string]$proc['Name'], $procId, $_.Exception.Message)
        }
    }
    # 无论成败都让快照过期：调用方马上会重新检测，命中旧快照会误判「仍在运行」
    $null = Set-WinstState -Name WinstProcessCache -Value ($null)
    return @{ Stopped = $stopped; Failed = $failed }
}
