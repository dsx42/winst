#Requires -Version 5.1

function Write-WinstPlanCommandStage {
    <#
    .SYNOPSIS
        ⑤ 安装后命令段（渲染口径与执行器一致：先展开 %VAR%、再展开占位符，仍未定路径才按安装目录相对路径处理）。
    #>
    param($Plan, [hashtable]$View)

    $commandLines = @()
    foreach ($command in @(Get-EntryArray -Entry $Plan -Key 'postInstall')) {
        $exeText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'exe') -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot))
        if ($View.InstallDir -and $exeText -and -not [IO.Path]::IsPathRooted($exeText)) { $exeText = Join-Path $View.InstallDir $exeText }
        $argText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'args') -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot))
        $line = $exeText
        if ($argText) { $line += ' ' + $argText }
        $line += ('    最长等待 {0} 秒' -f (Get-EntryInt -Entry $command -Key 'timeoutSec' -Default 600))
        $commandLines += $line
    }
    Write-ResolvedStage -Marker '⑤' -Label '命令' -Lines $commandLines
}
