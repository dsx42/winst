#Requires -Version 5.1

function Format-WinstManifestRefreshMessage {
    <#
    .SYNOPSIS
        刷新结果消息（本地 / 已是最新 / 刷新成功三种前缀；按需解析时附「按需解析 x / y」）。
    .OUTPUTS
        [string]
    #>
    param([switch]$IsLocal, [switch]$ReusedFromCache, [string]$Version, [int]$EntryCount,
        [int]$Succeeded, [int]$Failed, [int]$ResolvedCount, [switch]$OnDemand, [string]$RetainNote)

    $prefix = '刷新成功'
    if ($ReusedFromCache) { $prefix = '清单已是最新' }
    if ($IsLocal) { $prefix = '已读取本地清单' }
    if ($OnDemand) {
        return ('{0}，版本 {1}；按需解析 {2} / {3} 个软件，可用 {4} / 有误 {5}{6}' -f `
            $prefix, (Format-ManifestVersion -Version $Version), $ResolvedCount, $EntryCount, $Succeeded, $Failed, $RetainNote)
    }
    return ('{0}，版本 {1}；共 {2} 个软件，可用 {3} / 有误 {4}{5}' -f `
        $prefix, (Format-ManifestVersion -Version $Version), $EntryCount, $Succeeded, $Failed, $RetainNote)
}
