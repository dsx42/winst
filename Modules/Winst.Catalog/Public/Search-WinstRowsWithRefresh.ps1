#Requires -Version 5.1

function Search-WinstRowsWithRefresh {
    <#
    .SYNOPSIS
        先按缓存搜索，再按需刷新命中软件的版本信息，有刷新成果时重新搜索。
    .DESCRIPTION
        菜单「安装软件」与 CLI `winst search` 共用「搜索 → 取命中 id → 按需刷新 → 重搜」。
        搜索只覆盖解析锁（meta 的 apps）：解析锁里零命中时，先按各源清单正文再找一遍并解析命中的条目
        （Resolve-WinstDeclaredKeywordMatches），清单正文里也没有才算真的搜不到。
    .OUTPUTS
        @{ Searched = <Search-WinstRowsByKeywords 的结果>; Refresh = <Update-WinstDisplaySources 的结果> }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Keyword,
        [switch]$Quiet
    )

    $searched = Search-WinstRowsByKeywords -Context $Context -Keyword $Keyword

    # 解析锁里没有命中的，可能只是「清单里有、还没解析过」：再按清单正文找一遍，命中就解析后重搜
    $discovered = @{ Refreshed = 0; Failed = 0; Skipped = $false; Errors = @() }
    if (@($searched.Rows).Count -eq 0) {
        $discovered = Resolve-WinstDeclaredKeywordMatches -Context $Context -Keyword $Keyword -Quiet:$Quiet
        if ([int]$discovered.Refreshed -gt 0) {
            $searched = Search-WinstRowsByKeywords -Context $Context -Keyword $Keyword
        }
    }

    $hitIds = @(Get-WinstDisplayIds -Items $searched.Rows)
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $hitIds -Quiet:$Quiet
    if ([int]$refresh.Refreshed -gt 0) {
        $searched = Search-WinstRowsByKeywords -Context $Context -Keyword $Keyword
    }

    # 两段刷新合并上报：调用方只看 Refresh 的 Errors / Skipped，正文补找产生的错误不能丢
    $refresh.Refreshed = [int]$refresh.Refreshed + [int]$discovered.Refreshed
    $refresh.Failed = [int]$refresh.Failed + [int]$discovered.Failed
    $refresh.Skipped = ([bool]$refresh.Skipped -or [bool]$discovered.Skipped)
    $refresh.Errors = @($discovered.Errors) + @($refresh.Errors)
    return @{ Searched = $searched; Refresh = $refresh }
}
