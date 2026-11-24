#Requires -Version 5.1

function Get-WinstUpdateCheckBuckets {
    <#
    .SYNOPSIS
        归类「检查更新」的可更新项、无法比较项和失败项，并统计已是最新的条目。
    .OUTPUTS
        @{ UpdatableIds; UpdateEntries; Uncomparable; FailedEntries; LatestCount; SummaryText }
    .DESCRIPTION
        「可以更新」= `Action = check`（有更新版本、以及「无法比较版本」但按软件源定义更新这两类）
        **加上** `Action = files`（主包无变化、只有附加文件有更新）。`UpdatableIds` 与 `UpdateEntries`
        由同一次遍历产出、顺序严格一致，因此菜单里显示的编号可以直接当索引去取 id。
        **分类只在这里做一份**：菜单直接复用这里的分类结果，避免 `files` 漏进可更新集合、
        而展示列表里有它 → 编号错位（会更新到另一个软件），这条注释就是为此留的。
    #>
    param($Entries)

    $updateEntries = @()
    $uncomparable = @()
    $failedEntries = @()
    $latestCount = 0
    $unknownInUpdatable = 0
    $companionUpdatable = 0

    foreach ($one in @($Entries)) {
        $action = [string]$one['Action']
        if ($action -eq 'check' -or $action -eq 'files') {
            $updateEntries += $one
            if ($action -eq 'files') {
                $companionUpdatable++
            } elseif ([string]$one['Message']) {
                # 缺少可比较的版本号时，列表按条目说明原因。
                $unknownInUpdatable++
            }
            continue
        }
        if ($action -eq 'unknown' -or $action -eq 'newer') { $uncomparable += $one }
        elseif ($action -eq 'failed') { $failedEntries += $one }
        elseif ($action -eq 'latest') { $latestCount++ }
    }

    $notes = @()
    if ($unknownInUpdatable -gt 0) { $notes += ('{0} 个待核对版本' -f $unknownInUpdatable) }
    if ($companionUpdatable -gt 0) { $notes += ('{0} 个主包没变、只有附加文件有更新' -f $companionUpdatable) }
    $summaryText = ('共 {0} 个软件可以更新' -f $updateEntries.Count)
    if ($notes.Count -gt 0) {
        $summaryText = ('共 {0} 个软件可以更新（其中 {1}）' -f $updateEntries.Count, ($notes -join '；'))
    }

    return @{
        UpdatableIds       = @(foreach ($entry in $updateEntries) { [string]$entry['Id'] })
        UpdateEntries      = @($updateEntries)
        Uncomparable       = @($uncomparable)
        FailedEntries      = @($failedEntries)
        LatestCount        = $latestCount
        SummaryText        = $summaryText
    }
}
