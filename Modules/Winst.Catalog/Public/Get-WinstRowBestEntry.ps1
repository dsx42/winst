#Requires -Version 5.1

function Get-WinstRowBestEntry {
    <#
    .SYNOPSIS
        取一行里可用的最高版本**及其来源**（只统计可用来源；没有可用版本返回 $null）。
    .DESCRIPTION
        Get-WinstRowBestSourceEntry 的轻量投影：只需要「来源名 + 版本号」的调用方用它，
        避免把整条 entry（含 Plan）传出去。
    .OUTPUTS
        @{ Source; Version } 或 $null
    #>
    param($Row)

    $best = Get-WinstRowBestSourceEntry -Row $Row
    if (-not $best) { return $null }
    return @{ Source = [string]$best['Source']; Version = [string]$best['Version'] }
}
