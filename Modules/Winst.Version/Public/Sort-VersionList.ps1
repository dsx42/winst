#Requires -Version 5.1

function Sort-VersionList {
    <#
    .SYNOPSIS
        把版本号列表按从高到低排序：semver/ text（字符串序）。
    .DESCRIPTION
        供版本列表页源按「最新优先」逐个候选校验安装包是否真的可以下载（只取最大版本的话，
        遇到尚未发布正式包的版本目录会解析出无效地址）。列表规模即页面上的版本数，采用插入排序。
    #>
    param(
        [string[]]$Versions,
        [string]$SortMode = 'semver'
    )

    $mode = ''
    if ($null -ne $SortMode) { $mode = ([string]$SortMode).Trim().ToLowerInvariant() }

    $sorted = New-Object System.Collections.ArrayList
    foreach ($item in @($Versions)) {
        if ($null -eq $item -or -not ([string]$item).Trim()) { continue }
        $candidate = ([string]$item).Trim()

        # 二分找插入点：仍插在「第一个比候选小的元素」之前，相等时排在已有元素之后
        $low = 0
        $high = $sorted.Count
        while ($low -lt $high) {
            # 必须向下取整：PowerShell 的 [int] 对 .5 是银行家舍入，mid 可能等于 high 导致死循环
            $mid = [int][math]::Floor(($low + $high) / 2)
            $compare = 0
            if ($mode -eq 'text') {
                $compare = [string]::Compare($candidate, [string]$sorted[$mid], [StringComparison]::Ordinal)
            } else {
                $compare = Compare-WinstVersion -A $candidate -B ([string]$sorted[$mid])
            }
            if ($compare -gt 0) { $high = $mid } else { $low = $mid + 1 }
        }
        $sorted.Insert($low, $candidate)
    }
    return $sorted.ToArray()
}
