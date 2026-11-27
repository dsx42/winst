#Requires -Version 5.1

function Split-WinstKillableProcesses {
    <#
    .SYNOPSIS
        把匹配到的进程分成「可自动结束」与「需用户确认」两组。
    .DESCRIPTION
        只有已确认路径位于该软件目录下、且已取得启动时间的进程才允许自动关闭。
        关闭前须再次核对进程路径和启动时间。其余进程需用户手动关闭。
    .OUTPUTS
        @{ Killable; Blocked }
    #>
    param($Processes)

    $killable = New-Object 'System.Collections.Generic.List[object]'
    $blocked = New-Object 'System.Collections.Generic.List[object]'
    foreach ($proc in @($Processes)) {
        if ($null -eq $proc) { continue }
        if ([bool]$proc['Certain']) { $killable.Add($proc) } else { $blocked.Add($proc) }
    }
    return @{ Killable = @($killable.ToArray()); Blocked = @($blocked.ToArray()) }
}
