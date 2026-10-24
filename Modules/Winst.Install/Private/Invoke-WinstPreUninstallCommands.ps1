#Requires -Version 5.1

function Invoke-WinstPreUninstallCommands {
    <#
    .SYNOPSIS
        ⓪ 卸载命令（uninstall.commands）：删目录 / 跑官方卸载器**之前**执行。
    .DESCRIPTION
        这类命令要在程序文件还在原地时跑（如 MPC-VR 用 `regsvr32 /u` 注销 DirectShow 滤镜）；
        失败即中止卸载：安装目录与安装记录都保留，让用户先解决（如「以管理员身份运行 winst」）；
        `--force` 跳过卸载命令，用于「已手动注销、只想删干净」的情形。
    .OUTPUTS
        @{ Ok; Error; Notes }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, [bool]$ForceRemove, [switch]$Quiet)

    $notes = @()
    $uninstallCommands = @($Targets['Commands'])
    if ($uninstallCommands.Count -eq 0 -or [string]$Targets['Method'] -eq 'record-only') {
        return @{ Ok = $true; Error = ''; Notes = @() }
    }
    if ($ForceRemove) {
        $notes += '已按 --force 跳过卸载命令'
        return @{ Ok = $true; Error = ''; Notes = $notes }
    }

    $commandDir = [string]$Targets['InstallDir']
    if (-not $commandDir) { $commandDir = Join-Path $Context.InstallRoot $Id }
    if (-not $Quiet) {
        foreach ($command in $uninstallCommands) {
            $exeText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'exe') -InstallDir $commandDir -InstallRoot $Context.InstallRoot))
            $argsText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'args') -InstallDir $commandDir -InstallRoot $Context.InstallRoot))
            Write-Host (('    正在执行卸载命令: {0} {1}' -f $exeText, $argsText).TrimEnd()) -ForegroundColor Gray
        }
    }
    $run = Invoke-WinstCommandList -Commands $uninstallCommands -Label '卸载命令' -InstallDir $commandDir -InstallRoot $Context.InstallRoot
    if (-not $run.Ok) {
        return @{ Ok = $false; Error = ('{0}；安装目录与安装记录均未改动。如已手动处理过这一步，可加 --force 跳过卸载命令。' -f $run.Error); Notes = $notes }
    }
    return @{ Ok = $true; Error = ''; Notes = $notes }
}
