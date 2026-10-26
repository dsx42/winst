#Requires -Version 5.1

function Show-WinstInstalledDetail {
    <#
    .SYNOPSIS
        已安装软件的详情页（版本、安装位置、来源、管理方式、可更新情况、卸载时会回收的系统项）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    Write-WinstDetailHeader -Item $Item

    # 版本行：本机版本 + 一句结论（可更新 / 已是最新 / 本机更新 / 无法比较 / 软件源里没有），
    # 软件源最高版本与它的来源都写在同一行里，不单独重复「软件源最新版」与「软件源里的版本」。
    Write-Host ('    本机版本 : {0}' -f [string]$Item['Version']) -NoNewline -ForegroundColor Gray
    $latestText = '未知'
    if ([string]$Item['LatestVersion']) { $latestText = [string]$Item['LatestVersion'] }
    switch ([string]$Item['UpdateState']) {
        'update' {
            Write-Host ('    {0}' -f [string]$Item['UpdateHint']) -ForegroundColor Green
        }
        'latest' {
            Write-Host ('    已是最新（软件源里最高 {0}）' -f $latestText) -ForegroundColor Gray
        }
        'newer' {
            Write-Host ('    软件源里最高 {0}，比本机旧（不会自动降级；要重装 / 降级请到「安装软件」里搜索它，按提示确认强制重装）' -f $latestText) -ForegroundColor DarkYellow
        }
        'unknown' {
            if ([string]$Item['LatestSource']) {
                Write-Host ('    软件源里最高 {0}（来自 {1}），和本机版本没法自动比较' -f $latestText, [string]$Item['LatestSource']) -ForegroundColor DarkYellow
            } else {
                Write-Host '    软件源里没有可用的版本信息' -ForegroundColor DarkYellow
            }
        }
        default {
            Write-Host '    软件源里没有这个软件' -ForegroundColor DarkYellow
        }
    }

    # 其它来源的版本（最高版本与它的来源已在上面一行里给出，这里只补剩下的，避免重复）
    if ([string]$Item['OtherSourcesText']) {
        Write-Host ('    其它来源 : {0}' -f [string]$Item['OtherSourcesText']) -ForegroundColor DarkGray
    }

    # 本机并存的旧版本：同一个软件装过多个版本时（如 .NET 运行时升级后旧构建仍在），
    # 只展示最新版本会让人以为旧版本已经没了；这里明说并存了哪些，并给出清理入口
    if ([bool]$Item['HasOldVersions']) {
        Write-Host ('    旧版本   : {0}（仍安装在本机，可清理）' -f [string]$Item['OldVersionsText']) -ForegroundColor DarkYellow
    }

    Write-Host ('    类型     : {0}' -f [string]$Item['TypeText']) -ForegroundColor Gray

    Write-WinstDetailDependencies -Context $Context -Item $Item

    Write-Host ('    安装方式 : {0}' -f [string]$Item['ManagedText']) -ForegroundColor Gray
    $dirText = '（未记录）'
    if ([string]$Item['InstallDir']) { $dirText = [string]$Item['InstallDir'] }
    Write-Host ('    安装位置 : {0}' -f $dirText) -NoNewline -ForegroundColor Gray
    if ([bool]$Item['DirMissing']) { Write-Host '   [不存在]' -ForegroundColor Yellow } else { Write-Host '' }

    # 已下载的安装包（缓存索引 + 缓存目录）：路径、版本与文件，更新 / 安装时可直接复用
    Write-Host ('    安装包   : ') -NoNewline -ForegroundColor Gray
    if (-not [bool]$Item['CacheHas']) {
        Write-Host '无（安装 / 更新时会自动下载）' -ForegroundColor DarkGray
    } else {
        Write-Host ('{0}' -f [string]$Item['CacheDir']) -NoNewline -ForegroundColor Gray
        $cacheVersionText = '未知'
        if ([string]$Item['CacheVersion']) { $cacheVersionText = [string]$Item['CacheVersion'] }
        Write-Host ('    版本 {0}' -f $cacheVersionText) -NoNewline -ForegroundColor Gray
        $fileCount = @($Item['CacheFiles']).Count
        if ($fileCount -gt 0) { Write-Host ('（{0} 个文件）' -f $fileCount) -NoNewline -ForegroundColor DarkGray }
        if ([bool]$Item['CacheDirMissing']) { Write-Host '   [目录不存在，需要时会重新下载]' -ForegroundColor Yellow } else { Write-Host '' }
    }

    $installedAt = [string]$Item['InstalledAt']
    if ($installedAt) {
        $when = $installedAt
        $stamp = [datetime]::MinValue
        if ([datetime]::TryParse($installedAt, [ref]$stamp)) { $when = $stamp.ToString('yyyy-MM-dd HH:mm:ss') }
        Write-Host ('    安装时间 : {0}' -f $when) -ForegroundColor Gray
    }
    $updatedAt = [string]$Item['UpdatedAt']
    if ($updatedAt -and $updatedAt -ne $installedAt) {
        $when = $updatedAt
        $stamp = [datetime]::MinValue
        if ([datetime]::TryParse($updatedAt, [ref]$stamp)) { $when = $stamp.ToString('yyyy-MM-dd HH:mm:ss') }
        Write-Host ('    更新时间 : {0}（最近一次写入安装记录）' -f $when) -ForegroundColor Gray
    }
    if ([string]$Item['ManifestOrigin']) {
        Write-Host ('    来自软件源: {0} （更新默认用它）' -f [string]$Item['ManifestOrigin']) -ForegroundColor Gray
    } else {
        Write-Host '    来自软件源: （未记录，更新按默认优先级选来源）' -ForegroundColor DarkGray
    }

    $uninstallTargets = Get-WinstUninstallTargets -Context $Context -Id ([string]$Item['Id']) -Entry $Item['Ledger']
    $cleanup = @($uninstallTargets['CleanupItems'])
    Write-Host ''
    if ([string]$Item['Managed'] -ne 'winst') {
        Write-Host '    卸载时会移除安装记录；该软件不是 winst 安装的，程序本身与系统设置不会被改动' -ForegroundColor DarkGray
    } else {
        Write-Host ('    卸载动作来源: {0}' -f (@($uninstallTargets['Sources']) -join ' + ')) -ForegroundColor DarkGray
        if ($cleanup.Count -eq 0) {
            Write-Host '    卸载时会删除安装目录，没有需要回收的环境变量 / PATH 项 / 快捷方式' -ForegroundColor DarkGray
        } else {
            Write-Host '    卸载时会回收：' -ForegroundColor DarkGray
            foreach ($one in $cleanup) {
                Write-Host ('      - {0}: {1}' -f [string]$one['Kind'], [string]$one['Text']) -ForegroundColor DarkGray
            }
        }
    }
}
