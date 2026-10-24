#Requires -Version 5.1

function Save-WinstManifestRefresh {
    <#
    .SYNOPSIS
        落盘：需要时写清单缓存，并改写 sidecar 的更新时间与解析锁。
    .OUTPUTS
        @{ Error }
    #>
    param([hashtable]$Context, [string]$Name, [string]$CachePath, [string]$Content, [switch]$WriteCache,
        [string]$TargetUrl, [string]$Version, $Apps, [string]$FetchedAt)

    # 每次刷新都改写更新时间（即使清单内容未变、复用缓存）：多机共用安装包位置时据此确认刷新时刻
    try {
        if ($WriteCache) { Write-FileAtomic -Path $CachePath -Content $Content }
        Write-ManifestMeta -PkgDir $Context.PkgDir -Name $Name -Url $TargetUrl -Version $Version `
            -FetchedAt $FetchedAt -ResolvedAt (Get-Date).ToString('s') -Apps $Apps
    } catch {
        return @{ Error = ('写入缓存失败: {0}' -f $_.Exception.Message) }
    }
    return @{ Error = '' }
}
