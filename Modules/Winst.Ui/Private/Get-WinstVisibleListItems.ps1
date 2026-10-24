#Requires -Version 5.1

function Get-WinstVisibleListItems {
    <#
    .SYNOPSIS
        按关键字过滤列表项，并给出可见项在**原数组**里的下标（「编号 → 原始下标」的映射）。
    .DESCRIPTION
        菜单的三个列表页（已装软件 / 已下载包 / 软件列表）共用：列表太长时用户可直接输入软件名
        过滤，命中后仍按 1..N 输入编号选择——调用方用 Indexes 把编号换回原数组下标，
        因此「过滤后选中的仍是同一项」。$Filter 为空时原样返回（下标 0..N-1）。
    .OUTPUTS
        @{ Visible = @(项); Indexes = @(原下标) }
    #>
    param($Items, [string]$Filter)

    $all = @($Items)
    $visible = New-Object 'System.Collections.Generic.List[object]'
    $indexes = New-Object 'System.Collections.Generic.List[int]'
    $keyword = ''
    if ($null -ne $Filter) { $keyword = ([string]$Filter).Trim() }

    for ($i = 0; $i -lt $all.Count; $i++) {
        if ($keyword -and -not (Test-WinstListItemKeyword -Item $all[$i] -Keyword $keyword)) { continue }
        $visible.Add($all[$i])
        $indexes.Add($i)
    }
    return @{ Visible = @($visible.ToArray()); Indexes = @($indexes.ToArray()) }
}
