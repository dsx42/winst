#Requires -Version 5.1

function Get-WinstListItemStatus {
    <#
    .SYNOPSIS
        清单条目的一句话状态（安装视角：已装 / 已有安装包 / 需联网下载）。
    .OUTPUTS
        @{ Text; Color }
    #>
    param($Item)

    if (-not [bool]$Item['InCatalog']) { return @{ Text = '软件源里没有这个软件'; Color = 'DarkYellow' } }
    # 软件源里有条目、但没有任何可用版本（清单有误 / 全部来源不可用）：不能下载，也不能安装
    if (-not [string]$Item['BestVersion']) { return @{ Text = '软件源里没有可用的版本信息（清单有误 / 不可用）'; Color = 'DarkYellow' } }

    if ([bool]$Item['Installed']) {
        $text = ('已安装 {0}' -f [string]$Item['InstalledVersionText'])
        if ([string]$Item['UpdateState'] -eq 'update') {
            return @{ Text = ('{0}    ↑ 可更新到 {1}（来自 {2}）' -f $text, [string]$Item['BestVersion'], [string]$Item['BestSource']); Color = 'Green' }
        }
        if ([bool]$Item['InstalledDirMissing']) {
            return @{ Text = ($text + '   [安装目录不存在]'); Color = 'Yellow' }
        }
        return @{ Text = $text; Color = 'Gray' }
    }
    if ([bool]$Item['CacheHas']) { return @{ Text = ('已有安装包 {0}' -f [string]$Item['CacheVersionText']); Color = 'Gray' } }
    return @{ Text = '需联网下载'; Color = 'DarkYellow' }
}
