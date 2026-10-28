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
        # 目标盘不可用（如映射盘在提权进程里看不到）与「真的写不进去」要分开报告：
        # 前者是可恢复的环境问题，提示用户换 UNC 路径；两者的共同点是本次解析结果仍然可用，
        # 调用方不应把它当成「刷新失败 → 下次再来一遍」。
        $persistUnavailable = $false
        $message = $_.Exception.Message
        if ($message -match '目标盘当前不可用' -or
            $_.Exception -is [System.Management.Automation.DriveNotFoundException] -or
            $_.Exception -is [System.IO.DriveNotFoundException]) {
            $persistUnavailable = $true
        }
        return @{ Error = ('写入缓存失败: {0}' -f $message); PersistUnavailable = $persistUnavailable }
    }
    return @{ Error = ''; PersistUnavailable = $false }
}
