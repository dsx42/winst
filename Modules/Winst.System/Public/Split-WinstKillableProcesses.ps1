#Requires -Version 5.1

function Split-WinstKillableProcesses {
    <#
    .SYNOPSIS
        把匹配到的进程分成「可自动结束」与「需用户确认」两组。
    .DESCRIPTION
        Certain=$false 表示只是按进程名兜底匹配（可执行文件路径读不到，或不在安装目录下），
        可能是用户自己开的同名程序；这类不能自动杀，必须让用户确认。
        Certain=$true 是「路径确认位于该软件目录」或「进程名就是该软件主程序名」的进程。
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
