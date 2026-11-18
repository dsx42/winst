#Requires -Version 5.1

function Expand-WinstPlanCommand {
    <#
    .SYNOPSIS
        展开清单命令的程序路径和参数，供计划展示与进程启动共用。
    #>
    param($Command, [string]$InstallDir, [string]$InstallRoot)

    # 先展开清单中的环境变量，保留实际安装路径里字面的 %VAR%。
    $exe = [Environment]::ExpandEnvironmentVariables((Get-EntryString -Entry $Command -Key 'exe'))
    $arguments = [Environment]::ExpandEnvironmentVariables((Get-EntryString -Entry $Command -Key 'args'))
    $exe = Expand-PlanPlaceholders -Value $exe -InstallDir $InstallDir -InstallRoot $InstallRoot
    $arguments = Expand-PlanPlaceholders -Value $arguments -InstallDir $InstallDir -InstallRoot $InstallRoot
    $pathSafe = Test-WinstArgumentSafe -Value $exe
    if ($pathSafe -and $exe -and -not [IO.Path]::IsPathRooted($exe)) { $exe = Join-WinstPath $InstallDir $exe }
    return @{ Exe = $exe; Arguments = $arguments; PathSafe = $pathSafe }
}
