#Requires -Version 5.1

function Get-WinstRowBestSourceEntry {
    <#
    .SYNOPSIS
        取一行里可用来源中版本最高的那条来源记录（含 Plan）；没有可用来源时返回 $null。
    .DESCRIPTION
        **这是「取最高可用版本」的唯一实现**：Get-WinstRowBestEntry 与 Get-WinstRowBestPlanEntry
        都投影自它，比较规则只在这里定义一次。
        只统计可用来源（Ok = $true）且版本非空；同版本取先出现的（`-gt` 严格大于才替换）。
    .OUTPUTS
        @{ Source; Version; Ok; Error; Plan } 或 $null
    #>
    param($Row)

    if (-not $Row) { return $null }
    $best = $null
    foreach ($entry in @($Row['Sources'])) {
        if (-not $entry['Ok']) { continue }
        $version = [string]$entry['Version']
        if (-not $version) { continue }
        if ($null -eq $best -or (Compare-WinstVersion -A $version -B ([string]$best['Version'])) -gt 0) { $best = $entry }
    }
    return $best
}
