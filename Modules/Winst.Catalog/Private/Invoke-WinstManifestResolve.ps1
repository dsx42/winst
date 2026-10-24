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

    if ($OnlySet) {
        Write-Host ('  正在按需解析 {0} 个软件的最新版本 …' -f $onlyIdArgs.Count) -ForegroundColor Gray
    } else {
        Write-Host ('  正在读取 {0} 个软件的可用版本 …' -f $entries.Count) -ForegroundColor Gray
    }
    $summary = Resolve-ManifestApps -Context $Context -ManifestOrigin $Name -Entries $entries -OnlyIds $onlyIdArgs

    return @{ Apps = @($summary.Apps); Succeeded = [int]$summary.Succeeded; Failed = [int]$summary.Failed }
}
