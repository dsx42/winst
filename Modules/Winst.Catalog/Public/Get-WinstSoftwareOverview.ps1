#Requires -Version 5.1

function Get-WinstSoftwareOverview {
    <#
    .SYNOPSIS
        列出**软件源里的全部软件**，并合并「安装状态」「下载状态」与版本信息（菜单「软件列表」用）。
    .DESCRIPTION
        数据来源三处，各读一次（不额外联网）：软件清单（`Get-WinstSearchCatalog`，取自已刷新的软件清单）、
        安装记录（state.json）、安装包缓存索引（`pkgDir\winst.json`）。
        只列**软件源里的软件**：本机已装但软件源里没有的条目不在本页（请在「已装软件」里查看 / 卸载）。
    .OUTPUTS
        @{ Ok; Error; Warning; Items; CacheIndex }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $result = @{ Ok = $false; Error = ''; Warning = ''; Items = @(); CacheIndex = $null }

    # 台账：读不到（版本过高）时无法判断「是否已安装」，明确报错而不是把已装软件显示成未安装
    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        $result.Error = $stateRead.Error
        return $result
    }
    if ($stateRead.Error) { $result.Warning = $stateRead.Error }

    # 缓存索引（目录已不存在的条目会被自动剔除）+ 各 id 目录里的真实文件与大小
    $cacheIndex = New-WinstOrdinalDictionary
    if ($Context.PkgDir) {
        $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
        if ($cacheRead.Error -and -not $result.Warning) { $result.Warning = $cacheRead.Error }
        $cacheIndex = $cacheRead.Index
    }
    $result.CacheIndex = $cacheIndex

    $entryByCiId = Get-WinstCacheEntryMap -CacheIndex $cacheIndex
    $packageDirs = Get-WinstPackageDirectoryMap -PkgDir $Context.PkgDir

    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($row in @(Get-WinstSearchCatalog -Context $Context)) {
        $id = [string]$row['Id']
        if (-not $id) { continue }

        $ledger = Get-WinstInstalledApp -State $stateRead.State -Id $id

        $cacheDir = ''
        $cacheFiles = @()
        $sizeBytes = [long]0
        $cacheVersion = ''
        if ($packageDirs.ContainsKey($id)) {
            $cacheInfo = $packageDirs[$id]
            $cacheDir = [string]$cacheInfo['Path']
            $cacheFiles = @($cacheInfo['Files'])
            $sizeBytes = [long]$cacheInfo['SizeBytes']
        }
        if ($entryByCiId.ContainsKey($id)) { $cacheVersion = Get-EntryString -Entry $entryByCiId[$id] -Key 'version' }

        $items.Add((New-WinstSoftwareItem -Context $Context -Id $id -Row $row -Ledger $ledger `
            -CacheDir $cacheDir -CacheFiles $cacheFiles -CacheSizeBytes $sizeBytes -CacheVersion $cacheVersion))
    }

    # 用 @() 包住函数调用：PowerShell 里「函数返回空数组」到调用方会变成 $null，
    # 而调用方普遍写 `@($overview.Items)` —— $null 会变成「1 个 $null 条目」，
    # 于是空列表页会显示「共 1 个…」并在渲染时抛「Cannot index into a null array」。
    $result.Items = @(Sort-WinstRowsByGroup -Rows $items -ByName)
    $result.Ok = $true
    return $result
}
