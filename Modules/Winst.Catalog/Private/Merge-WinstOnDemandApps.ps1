#Requires -Version 5.1

function Merge-WinstOnDemandApps {
    <#
    .SYNOPSIS
        按需解析（OnlyIds）后：未解析的条目沿用 sidecar 既有解析锁缓存，结果顺序以本次清单条目为准。
    .DESCRIPTION
        版本与 per-app resolvedAt 原样保留，不受本次解析成败影响；清单中已移除的条目自然清退；
        从未解析过且不在本次集合里的条目不产出占位行，等真正需要展示它的页面触发解析
        。
    .OUTPUTS
        @{ Apps; Resolved }
    #>
    param($Apps, $Entries, $Meta)

    $previousApps = @()
    if ($Meta -and $Meta.HasApps) { $previousApps = @($Meta.Apps) }
    $prevMap = New-WinstOrdinalDictionary
    foreach ($oldApp in $previousApps) {
        $oldId = Get-EntryString -Entry $oldApp -Key 'id'
        if ($oldId -and -not $prevMap.Contains($oldId)) { $prevMap[$oldId] = $oldApp }
    }
    $resolvedMap = New-WinstOrdinalDictionary
    foreach ($app in @($Apps)) {
        $id = Get-EntryString -Entry $app -Key 'id'
        if ($id) { $resolvedMap[$id] = $app }
    }

    $merged = @(foreach ($entry in @($Entries)) {
        $id = Get-EntryString -Entry $entry -Key 'id'
        if ($id -and $resolvedMap.Contains($id)) { $resolvedMap[$id] }
        elseif ($id -and $prevMap.Contains($id)) { $prevMap[$id] }
    })
    return @{ Apps = $merged; Resolved = $resolvedMap.Count }
}
