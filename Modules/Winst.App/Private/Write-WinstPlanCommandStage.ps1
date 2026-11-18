#Requires -Version 5.1

function Write-WinstPlanCommandStage {
    <#
    .SYNOPSIS
        ⑤ 安装后命令段（渲染口径与执行器一致：先展开 %VAR%、再展开占位符，仍未定路径才按安装目录相对路径处理）。
    #>
    param($Plan, [hashtable]$View)

    $commandLines = @()
    foreach ($command in @(Get-EntryArray -Entry $Plan -Key 'postInstall')) {
        $expanded = Expand-WinstPlanCommand -Command $command -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot
        $line = $expanded.Exe
        if ($expanded.Arguments) { $line += ' ' + $expanded.Arguments }
        $timeoutSec = Get-EntryInt -Entry $command -Key 'timeoutSec' -Default 600
        if ($timeoutSec -le 0) { $timeoutSec = 600 }
        $line += ('    最长等待 {0} 秒' -f $timeoutSec)
        $commandLines += $line
    }
    Write-ResolvedStage -Marker '⑤' -Label '命令' -Lines $commandLines
}
