#Requires -Version 5.1

function Get-WinstListItemPinNote {
    <#
    .SYNOPSIS
        清单里写了 `id==版本` 时的一句说明：与软件源一致 / 不一致 / 软件源没有版本信息，三种措辞；没写固定版本时返回空串。
    .OUTPUTS
        @{ Text; Color }
    #>
    param($Item)

    $pinned = [string]$Item['PinnedVersion']
    if (-not $pinned) { return @{ Text = ''; Color = 'DarkGray' } }
    if ([bool]$Item['PinMismatch']) {
        return @{ Text = ('清单指定 {0}，软件源里是 {1}（安装时会再确认）' -f $pinned, [string]$Item['BestVersion']); Color = 'DarkYellow' }
    }
    if ([bool]$Item['PinUnknown']) {
        return @{ Text = ('清单指定 {0}，软件源里没有可用的版本信息' -f $pinned); Color = 'DarkYellow' }
    }
    return @{ Text = ('清单指定 {0}（与软件源一致）' -f $pinned); Color = 'DarkGray' }
}
