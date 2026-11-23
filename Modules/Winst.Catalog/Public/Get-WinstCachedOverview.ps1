#Requires -Version 5.1

function Get-WinstCachedOverview {
    <#
    .SYNOPSIS
        读取已下载的安装包，产出「已下载包」视图（菜单与 CLI `winst list --cached` 共用）。
    .DESCRIPTION
        以安装包位置下实际含文件的 id 目录生成列表，读取缓存索引中的包版本，
        并合并安装台账与软件清单信息。读取时对索引的校对只作用于内存。
    .OUTPUTS
        @{ Ok; Error; Warning; Items }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context, $PackageDirs = $null)

    $result = @{ Ok = $false; Error = ''; Warning = ''; Items = @() }

    if (-not $Context.PkgDir) {
        $result.Error = '没有可用的安装包位置，无法列出已下载的安装包。'
        return $result
    }

    # 缓存索引：只读，不在这里回写（校对与重建由 repair / 下载流程负责）
    if ($null -eq $PackageDirs) { $PackageDirs = Get-WinstPackageDirectoryMap -PkgDir $Context.PkgDir }
    $ids = @($PackageDirs.Keys)
    if ($ids.Count) { $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids $ids }
    else { $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir }
    if ($cacheRead.Error) { $result.Warning = $cacheRead.Error }
    $cacheIndex = $cacheRead.Index

    # 台账：读不到（版本过高）时无法判断「是否已安装」，明确报错而不是把已装软件显示成未安装
    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot -Ids $ids
    if ($stateRead.Error -and -not $stateRead.Reset) {
        $result.Error = $stateRead.Error
        return $result
    }
    if ($stateRead.Error -and -not $result.Warning) { $result.Warning = $stateRead.Error }

    if ($ids.Count -eq 0) {
        $result.Ok = $true
        return $result
    }
    $rowById = Get-WinstCatalogRowMap -Context $Context -Ids $ids

    $sourceLookup = @{}
    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($idText in @($packageDirs.Keys)) {
        $cacheInfo = $packageDirs[$idText]
        $cacheVersion = ''
        if ($cacheIndex.Contains($idText)) { $cacheVersion = Get-EntryString -Entry $cacheIndex[$idText] -Key 'version' }

        $ledger = Get-WinstInstalledApp -State $stateRead.State -Id $idText
        $row = $null
        if ($rowById.Contains($idText)) { $row = $rowById[$idText] }

        $items.Add((New-WinstCachedItem -Context $Context -SourceLookup $sourceLookup -Id $idText -CacheDir ([string]$cacheInfo['Path']) `
            -CacheFiles @($cacheInfo['Files']) -CacheSizeBytes ([long]$cacheInfo['SizeBytes']) `
            -CacheVersion $cacheVersion -Ledger $ledger -Row $row -CacheIndex $cacheIndex))
    }

    # 用 @() 包住函数调用：PowerShell 里「函数返回空数组」到调用方会变成 $null，
    # 而调用方普遍写 `@($overview.Items)` —— $null 会变成「1 个 $null 条目」，
    # 于是空列表页会显示「共 1 个…」并在渲染时抛「Cannot index into a null array」。
    $result.Items = @(Sort-WinstRowsByGroup -Rows $items -ByName)
    $result.Ok = $true
    return $result
}
