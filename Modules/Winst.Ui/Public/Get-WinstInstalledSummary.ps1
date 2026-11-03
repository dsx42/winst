#Requires -Version 5.1

function Get-WinstInstalledSummary {
    <#
    .SYNOPSIS
        按已准备的版本结论汇总安装列表，不把无法判断当成最新。
    #>
    param($Items, [string]$ItemNoun = '已安装软件')

    $list = @($Items)
    $counts = @{ latest = 0; update = 0; newer = 0; unknown = 0; missing = 0 }
    foreach ($item in $list) {
        $state = [string]$item['UpdateState']
        if (-not $counts.ContainsKey($state)) { $state = 'unknown' }
        $counts[$state]++
    }
    $parts = @()
    if ($list.Count -gt 0 -and $counts.latest -eq $list.Count) { $parts += '都是最新版本' }
    else {
        if ($counts.update -gt 0) { $parts += ('{0} 个可更新' -f $counts.update) }
        if ($counts.latest -gt 0) { $parts += ('{0} 个已是最新' -f $counts.latest) }
        if ($counts.newer -gt 0) { $parts += ('{0} 个本机版本较新' -f $counts.newer) }
        if ($counts.unknown -gt 0) { $parts += ('{0} 个无法判断' -f $counts.unknown) }
        if ($counts.missing -gt 0) { $parts += ('{0} 个没有软件源' -f $counts.missing) }
    }
    $color = 'DarkGray'
    if ($counts.update -gt 0) { $color = 'Green' }
    return @{ Text = ('共 {0} 个{1}    {2}' -f $list.Count, $ItemNoun, ($parts -join ' / ')); Color = $color; UpdateCount = $counts.update }
}
