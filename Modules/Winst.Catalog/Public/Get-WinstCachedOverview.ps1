#Requires -Version 5.1

function Get-WinstCachedOverview {
    <#
    .SYNOPSIS
        读取已下载的安装包，产出「已下载包」视图（菜单与 CLI `winst list --cached` 共用）。
    .DESCRIPTION
        数据来源三处，各读一次（不额外联网）：缓存索引 `<pkgDir>\winst.json`（`Read-WinstCacheIndex`，
        缺失 / 损坏时按各 id 目录内文件重建、目录已不存在的条目自动剔除）、安装记录 `state.json`、
        软件清单（`Get-WinstSearchCatalog`，取自已刷新的软件清单）。
        列表以**磁盘上真实存在包文件**的 id 为准：索引里的 id 与 <pkgDir> 下的目录都会纳入
        （目录存在但索引里没记录时，缓存版本显示「未知」，不做猜测）。
    .OUTPUTS
        @{ Ok; Error; Warning; Items; RowById; CacheIndex }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $result = @{ Ok = $false; Error = ''; Warning = ''; Items = @(); RowById = $null; CacheIndex = $null }

    if (-not $Context.PkgDir) {
        $result.Error = '没有可用的安装包位置，无法列出已下载的安装包。'
        return $result
    }

    # 缓存索引：只读，不在这里回写（校对与重建由 repair / 下载流程负责）
    $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    if ($cacheRead.Error) { $result.Warning = $cacheRead.Error }
    $cacheIndex = $cacheRead.Index
    $result.CacheIndex = $cacheIndex

    # 台账：读不到（版本过高）时无法判断「是否已安装」，明确报错而不是把已装软件显示成未安装
    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        $result.Error = $stateRead.Error
        return $result
    }
    if ($stateRead.Error -and -not $result.Warning) { $result.Warning = $stateRead.Error }

    $rowById = Get-WinstCatalogRowMap -Context $Context
    $result.RowById = $rowById

    $entryByCiId = Get-WinstCacheEntryMap -CacheIndex $cacheIndex
    $packageDirs = Get-WinstPackageDirectoryMap -PkgDir $Context.PkgDir

    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($idText in @($packageDirs.Keys)) {
        $cacheInfo = $packageDirs[$idText]
        $cacheVersion = ''
        if ($entryByCiId.ContainsKey($idText)) { $cacheVersion = Get-EntryString -Entry $entryByCiId[$idText] -Key 'version' }

        $ledger = Get-WinstInstalledApp -State $stateRead.State -Id $idText
        $row = $null
        if ($rowById.Contains($idText)) { $row = $rowById[$idText] }

        $items.Add((New-WinstCachedItem -Context $Context -Id $idText -CacheDir ([string]$cacheInfo['Path']) `
            -CacheFiles @($cacheInfo['Files']) -CacheSizeBytes ([long]$cacheInfo['SizeBytes']) `
            -CacheVersion $cacheVersion -Ledger $ledger -Row $row))
    }

    # 用 @() 包住函数调用：PowerShell 里「函数返回空数组」到调用方会变成 $null，
    # 而调用方普遍写 `@($overview.Items)` —— $null 会变成「1 个 $null 条目」，
    # 于是空列表页会显示「共 1 个…」并在渲染时抛「Cannot index into a null array」。
    $result.Items = @(Sort-WinstRowsByGroup -Rows $items -ByName)
    $result.Ok = $true
    return $result
}
