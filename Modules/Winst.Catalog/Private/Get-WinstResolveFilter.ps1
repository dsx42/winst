#Requires -Version 5.1

function Get-WinstResolveFilter {
    <#
    .SYNOPSIS
        构造按需解析的 id 集合（Ordinal）；-IncludeUnresolved 时把「缓存里从未解析过」的条目一并加入。
    .OUTPUTS
        哈希集合（未传 OnlyIds 时返回 $null）
    #>
    param($Entries, [string[]]$OnlyIds = @(), $Meta, [switch]$IncludeUnresolved)

    if (@($OnlyIds).Count -eq 0) { return $null }
    $onlySet = Get-WinstIdFilterSet -Ids $OnlyIds
    if (-not $IncludeUnresolved) { return $onlySet }

    # 清单里「从未解析过」的条目（缓存里没有 id）一并解析：上游新增的软件逐步补齐进解析锁
    $cachedIds = @()
    if ($Meta -and $Meta.HasApps) {
        foreach ($oldApp in @($Meta.Apps)) {
            $oldId = Get-EntryString -Entry $oldApp -Key 'id'
            if ($oldId) { $cachedIds += $oldId }
        }
    }
    $cachedSet = Get-WinstIdFilterSet -Ids $cachedIds
    foreach ($entry in @($Entries)) {
        $id = Get-EntryString -Entry $entry -Key 'id'
        if ($id -and -not $cachedSet.ContainsKey($id)) { $onlySet[$id] = $true }
    }
    return $onlySet
}
