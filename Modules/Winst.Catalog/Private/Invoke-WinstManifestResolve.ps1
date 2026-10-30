#Requires -Version 5.1

function Invoke-WinstManifestResolve {
    <#
    .SYNOPSIS
        逐条目解析最新版本（失败隔离），并打印一行进度说明。
    .OUTPUTS
        @{ Apps; Succeeded; Failed }
    #>
    param([hashtable]$Context, [string]$Name, $Entries, $OnlySet)

    $entries = @($Entries)
    $onlyIdArgs = @()
    if ($OnlySet) { $onlyIdArgs = @($OnlySet.Keys) }

    if ($entries.Count -eq 0) {
        Write-Host '  这个软件源里没有软件。' -ForegroundColor DarkGray
        return @{ Apps = @(); Succeeded = 0; Failed = 0 }
    }

    # 进度里的数字用「本次真正要解析的条目数」：OnlyIds 里不属于本源的 id 不算，
    # 否则会显示成「按需解析 13 个」而本源实际只解析其中几个
    $targetCount = $entries.Count
    if ($OnlySet) {
        $targetCount = 0
        foreach ($entry in $entries) {
            $entryId = Get-EntryString -Entry $entry -Key 'id'
            if ($entryId -and $OnlySet.ContainsKey($entryId)) { $targetCount++ }
        }
        # 显式给了 OnlyIds 却一条都不属于本源：本次没有要解析的条目。
        # 不能把空集合继续传下去——Resolve-ManifestApps 会把「没有过滤条件」当成全量解析
        if ($targetCount -eq 0) { return @{ Apps = @(); Succeeded = 0; Failed = 0 } }
    }

    if ($OnlySet) {
        Write-Host ('  正在按需解析 {0} 个软件的最新版本 …' -f $targetCount) -ForegroundColor Gray
    } else {
        Write-Host ('  正在读取 {0} 个软件的可用版本 …' -f $entries.Count) -ForegroundColor Gray
    }
    $summary = Resolve-ManifestApps -Context $Context -ManifestOrigin $Name -Entries $entries -OnlyIds $onlyIdArgs

    return @{ Apps = @($summary.Apps); Succeeded = [int]$summary.Succeeded; Failed = [int]$summary.Failed }
}
