#Requires -Version 5.1

function Sort-VersionList {
    <#
    .SYNOPSIS
        把版本号列表按从高到低排序：semver/ text（字符串序）。
    .DESCRIPTION
        供版本列表页源按「最新优先」逐个候选校验安装包是否真的可以下载（只取最大版本的话，
        遇到尚未发布正式包的版本目录会解析出无效地址）。相同版本按输入顺序输出。
    #>
    param(
        [string[]]$Versions,
        [string]$SortMode = 'semver'
    )

    $mode = $SortMode.Trim().ToLowerInvariant()

    $items = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in $Versions) {
        if ($item -and $item.Trim()) { $items.Add($item.Trim()) }
    }
    # 用原序号打破平局，保留版本相等时的输入顺序。
    $order = New-Object 'System.Collections.Generic.List[int]'
    for ($i = 0; $i -lt $items.Count; $i++) { $order.Add($i) }
    $order.Sort([Comparison[int]]{
        param($left, $right)
        if ($mode -eq 'text') { $c = [string]::CompareOrdinal($items[$right], $items[$left]) }
        else { $c = Compare-WinstVersion -A $items[$right] -B $items[$left] }
        if ($c) { return $c }
        return $left.CompareTo($right)
    })
    foreach ($i in $order) { $items[$i] }
}
