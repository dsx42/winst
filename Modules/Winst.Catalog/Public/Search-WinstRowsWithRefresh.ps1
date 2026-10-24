#Requires -Version 5.1

function Search-WinstRowsWithRefresh {
    <#
    .SYNOPSIS
        先按缓存搜索，再按需刷新命中软件的版本信息，有刷新成果时重新搜索。
    .DESCRIPTION
        菜单「安装软件」与 CLI `winst search` 共用「搜索 → 取命中 id → 按需刷新 → 重搜」。
    .OUTPUTS
        @{ Searched = <Search-WinstRowsByKeywords 的结果>; Refresh = <Update-WinstDisplaySources 的结果> }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Keyword,
        [switch]$Quiet
    )

    $searched = Search-WinstRowsByKeywords -Context $Context -Keyword $Keyword
    $hitIds = @(Get-WinstDisplayIds -Items $searched.Rows)
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $hitIds -Quiet:$Quiet
    if ([int]$refresh.Refreshed -gt 0) {
        $searched = Search-WinstRowsByKeywords -Context $Context -Keyword $Keyword
    }
    return @{ Searched = $searched; Refresh = $refresh }
}
