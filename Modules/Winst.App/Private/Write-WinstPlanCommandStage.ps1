#Requires -Version 5.1

function Write-WinstPlanCommandStage {
    <#
    .SYNOPSIS
        ⑤ 安装后命令段（渲染口径与执行器一致：先展开 %VAR%、再展开占位符，仍未定路径才按安装目录相对路径处理）。
    #>
    param($Plan, [hashtable]$View)

    $commandLines = @()
    foreach ($command in @(Get-EntryArray -Entry $Plan -Key 'postInstall')) {
        $exeText = Expand-PlanPlaceholders -Value ([Environment]::ExpandEnvironmentVariables((Get-EntryString -Entry $command -Key 'exe'))) -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot
        if ($View.InstallDir -and $exeText -and -not [IO.Path]::IsPathRooted($exeText)) { $exeText = Join-WinstPath $View.InstallDir $exeText }
        $argText = Expand-PlanPlaceholders -Value ([Environment]::ExpandEnvironmentVariables((Get-EntryString -Entry $command -Key 'args'))) -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot
        $line = $exeText
        if ($argText) { $line += ' ' + $argText }
        $timeoutSec = Get-EntryInt -Entry $command -Key 'timeoutSec' -Default 600
        if ($timeoutSec -le 0) { $timeoutSec = 600 }
        $line += ('    最长等待 {0} 秒' -f $timeoutSec)
        $commandLines += $line
    }
    Write-ResolvedStage -Marker '⑤' -Label '命令' -Lines $commandLines
}
