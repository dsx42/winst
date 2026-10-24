#Requires -Version 5.1

function Format-WinstUninstallMessage {
    <#
    .SYNOPSIS
        结果消息（带卸载掉的版本号；external 记录说明「程序本身与系统设置未改动」）。
    .OUTPUTS
        [string]
    #>
    param([string]$Id, $Targets)

    # 结果消息带上卸载掉的版本号（与安装侧「Rufus 4.15 已安装到 …」同一口径；版本未知时不硬凑）
    $versionText = [string]$Targets['Version']
    if ($versionText -ieq 'unknown') { $versionText = '' }
    $versionSuffix = ''
    if ($versionText) { $versionSuffix = ' ' + $versionText }
    if ($Targets['External']) {
        return ('{0}{1} 已从安装记录中移除（不是 winst 安装的，程序本身与系统设置未改动）' -f $Id, $versionSuffix)
    }
    return ('{0}{1} 已卸载' -f $Id, $versionSuffix)
}
