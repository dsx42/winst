#Requires -Version 5.1

function Get-WinstListItemPinNote {
    <#
    .SYNOPSIS
        清单里写了 `id==版本` 时的一句说明：按实际版本来源说明匹配、差异或版本未知；没写固定版本时返回空串。
    .OUTPUTS
        @{ Text; Color }
    #>
    param($Item)

    $pinned = [string]$Item['PinnedVersion']
    if (-not $pinned) { return @{ Text = ''; Color = 'DarkGray' } }
    $source = [string]$Item['PinSource']
    if ([bool]$Item['PinMismatch']) {
        return @{ Text = ('清单指定 {0}，{1}版本为 {2}' -f $pinned, $source, [string]$Item['PinVersion']); Color = 'DarkYellow' }
    }
    if ([bool]$Item['PinUnknown']) {
        return @{ Text = ('清单指定 {0}，{1}版本待确认' -f $pinned, $source); Color = 'DarkYellow' }
    }
    return @{ Text = ('清单指定 {0}（与{1}版本一致）' -f $pinned, $source); Color = 'DarkGray' }
}
