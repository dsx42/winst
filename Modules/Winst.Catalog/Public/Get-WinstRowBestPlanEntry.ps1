#Requires -Version 5.1

function Get-WinstRowBestPlanEntry {
    <#
    .SYNOPSIS
        取一行里「版本最高的可用来源」那一条（含它的 Plan），供只下载 / 打包流程直接使用。
    .DESCRIPTION
        没有明确远端版本时取第一个可用计划；版本待定或仅有缓存版本的计划仍可用于下载与安装。
        比较逻辑完全复用 Get-WinstRowBestSourceEntry，不先取投影再反查，少扫一遍 Sources。
    .OUTPUTS
        @{ Source; Version; Ok; Error; Plan } 或 $null
    #>
    param($Row)

    if (-not $Row) { return $null }
    $best = Get-WinstRowBestSourceEntry -Row $Row
    if ($best) { return $best }
    foreach ($candidate in @($Row['Sources'])) {
        if ($candidate['Ok'] -and $candidate['Plan']) { return $candidate }
    }
    return $null
}
