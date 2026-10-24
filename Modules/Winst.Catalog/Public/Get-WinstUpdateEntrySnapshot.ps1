#Requires -Version 5.1

function Get-WinstUpdateEntrySnapshot {
    <#
    .SYNOPSIS
        取一条软件的最新版本 / 来源 / 版本号来源 / 远端新鲜度 / 安装来源与版本比较结果。
    .OUTPUTS
        @{ Latest; LatestSource; VersionFromPackage; CachedPackageVersion; RemoteFresh; HasUsableSource;
           Comparable; Cmp; OriginName; OriginEntry; OriginVersion; OriginUsable; OriginNewer }
    #>
    param([hashtable]$Context, $Row, $Ledger, [string]$InstalledVersion)

    $bestEntry = Get-WinstRowBestEntry -Row $Row
    $latest = ''
    $latestSource = ''
    if ($bestEntry) {
        $latest = [string]$bestEntry['Version']
        $latestSource = [string]$bestEntry['Source']
    }

    # 版本号取自主包文件信息的条目：软件源里其实没有版本号，缓存里
    # 那份也不算数（要重新取包才知道当前是哪一版）→ 不拿它当比较基准，按「软件源里没有可用的版本信息」处理
    $versionFromPackageRow = Test-WinstRowVersionFromPackage -Row $Row
    $cachedPackageVersion = ''
    $remoteFreshState = ''
    if ($versionFromPackageRow) {
        $latest = ''
        $latestSource = ''
        # 「已下载安装包」的版本（解析锁 / 缓存索引）与远端新鲜度（解析时的 HEAD 结论）：
        # 供检查更新「三条件判已是最新」与目标版本展示用，读锁与本地索引、零网络请求
        $cachedPackageVersion = Get-WinstRowCachedPackageVersion -PkgDir $Context.PkgDir -Row $Row
        $remoteFreshState = Get-WinstRowRemoteFreshState -Row $Row
    }

    # 软件源里没有可用的版本信息时再分两种：
    #   ① 至少有一个来源可用（解析成功，只是没版本号）→ 仍算可更新，按软件源里的定义更新；
    #   ② 所有来源都解析失败 → 没有任何可用地址，标记 ResolutionError 排除在「可更新」外。
    $hasUsableSource = $false
    foreach ($candidate in @($Row['Sources'])) {
        if ($candidate['Ok']) { $hasUsableSource = $true; break }
    }

    # 安装时用的来源（更新默认用它）：供「是否可更新」判断与执行阶段共用
    $originName = Get-EntryString -Entry $Ledger -Key 'manifestOrigin'
    $originEntry = $null
    $originVersion = ''
    if ($originName) {
        foreach ($candidate in @($Row['Sources'])) {
            if ([string]$candidate['Source'] -ieq $originName) { $originEntry = $candidate; break }
        }
        if ($originEntry) { $originVersion = [string]$originEntry['Version'] }
    }

    $comparable = [bool]($InstalledVersion -and $InstalledVersion -ne 'unknown')
    $cmp = 0
    # 软件源里没有可用的版本信息时不比较版本（按软件源里的定义安装）
    if ($comparable -and $latest) { $cmp = Compare-WinstVersion -A $latest -B $InstalledVersion }

    # 安装来源自己有比本机更新的版本 → 同样算「可更新」（不同来源对同一版本的写法可能不同）
    $originUsable = [bool]($originEntry -and $originEntry['Ok'] -and $originVersion)
    $originNewer = $false
    if ($originUsable) {
        if ($comparable) {
            $originNewer = ((Compare-WinstVersion -A $originVersion -B $InstalledVersion) -gt 0)
        } else {
            $originNewer = $true
        }
    }
    if ($comparable -and $cmp -le 0 -and $originNewer) { $cmp = 1 }

    return @{
        Latest = $latest; LatestSource = $latestSource; VersionFromPackage = $versionFromPackageRow
        CachedPackageVersion = $cachedPackageVersion; RemoteFresh = $remoteFreshState
        HasUsableSource = $hasUsableSource; Comparable = $comparable; Cmp = $cmp
        OriginName = $originName; OriginEntry = $originEntry; OriginVersion = $originVersion
        OriginUsable = $originUsable; OriginNewer = $originNewer
    }
}
