#Requires -Version 5.1

function Search-WinstInstalledItemsByKeywords {
    <#
    .SYNOPSIS
        按「整串优先、搜不到再拆分多关键字合并」的规则在安装台账里搜索（菜单卸载流程用，与安装侧同一规则）。
    .DESCRIPTION
        1. 整串当一个关键字搜——软件名本身可能带空格（如「Eclipse Temurin JDK 21」），这样「一个名字」
           的输入行为不变；
        2. 整体没结果、且输入里含空格 / 逗号 / 顿号分隔的多个词时，按词分别搜索，按出现顺序合并、
           按 id 去重——「rufus 7-zip」这类输入能一次搜到多个软件，随后在列表里多选卸载。
        单关键字匹配 = 先精确匹配 id / 名称（写全名行为不变），再按子串；全程不区分大小写。
    .OUTPUTS
        @{ Items; Keywords; Merged; HitKeywords }
    #>
    param(
        [AllowEmptyCollection()]
        $Items = @(),
        [Parameter(Mandatory = $true)][string]$Keyword
    )

    $result = @{ Items = @(); Keywords = @($Keyword); Merged = $false; HitKeywords = @() }
    $all = @($Items)

    # 单关键字匹配（卸载口径）：先精确匹配 id / 名称，再按子串（均不区分大小写）
    $matchItems = {
        param([string]$Text)
        $found = @()
        foreach ($item in $all) {
            $idText = [string]$item['Id']
            $nameText = [string]$item['DisplayName']
            if ($idText -ieq $Text -or $nameText -ieq $Text) { $found += $item; continue }
            if ($idText -and $idText.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $found += $item; continue }
            if ($nameText -and $nameText.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $found += $item }
        }
        return $found
    }

    $hits = @(& $matchItems $Keyword)
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
        $found = @(& $matchItems $one)
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
