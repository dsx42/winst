#Requires -Version 5.1

function Merge-WinstKeywordSearch {
    <#
    .SYNOPSIS
        多关键字搜索的公共规则：整串优先，未命中再按分隔符拆词分别搜索、按 id 去重合并。
    .DESCRIPTION
        菜单安装侧（软件源条目）与卸载侧（安装台账条目）用的是同一套输入规则，只差「单个关键字
        怎么匹配」——那一步由调用方传 scriptblock（参数为单个关键字，返回命中的条目数组）。
        拆词分隔符、去重口径（Ordinal，按 Id）、命中词统计都在这里定义一次。
    .OUTPUTS
        @{ Items; Keywords; Merged; HitKeywords }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Keyword,
        [Parameter(Mandatory = $true)][scriptblock]$Match
    )

    $result = @{ Items = @(); Keywords = @($Keyword); Merged = $false; HitKeywords = @() }

    $hits = @(& $Match $Keyword)
    if ($hits.Count -gt 0) { $result.Items = @($hits); return $result }

    $parts = @()
    foreach ($token in @($Keyword -split '[\s,，、]+')) {
        $one = ([string]$token).Trim()
        if ($one -and ($parts -notcontains $one)) { $parts += $one }
    }
    if ($parts.Count -le 1) { return $result }

    $result.Keywords = @($parts)
    $result.Merged = $true
    $ids = New-WinstOrdinalDictionary
    $merged = @()
    foreach ($one in $parts) {
        $found = @(& $Match $one)
        if ($found.Count -gt 0) { $result.HitKeywords += $one }
        foreach ($item in $found) {
            $idText = [string]$item['Id']
            if (-not $idText -or $ids.Contains($idText)) { continue }
            $ids[$idText] = $true
            $merged += $item
        }
    }
    $result.Items = @($merged)
    return $result
}
