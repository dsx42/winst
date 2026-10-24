#Requires -Version 5.1

function Get-WinstListLookups {
    <#
    .SYNOPSIS
        为清单流程一次性准备好「软件源视图 + 安装记录 + 缓存索引 + 磁盘上的包文件」。
    .DESCRIPTION
        各读一次、不逐条联网（软件源刷新由调用方先用 Update-WinstStaleSources 完成）：
          ① RowById      —— 软件源里的软件（Get-WinstSearchCatalog）；
          ② State        —— 安装记录；
          ③ CacheIndex   —— <pkgDir>\winst.json；
          ④ CacheDirById —— 安装包位置下真实存在包文件的目录（索引可能过期，以磁盘为准）。
        只查本地缓存、不联网，用于「需联网下载 / 已有安装包」的判定。
    .OUTPUTS
        @{ Ok; Error; Warning; RowById; State; CacheIndex; CacheDirById }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $result = @{ Ok = $false; Error = ''; Warning = ''; RowById = $null; State = $null; CacheIndex = $null; CacheDirById = $null }

    $result.RowById = Get-WinstCatalogRowMap -Context $Context

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        $result.Error = $stateRead.Error
        return $result
    }
    if ($stateRead.Error) { $result.Warning = $stateRead.Error }
    $result.State = $stateRead.State

    $cacheIndex = New-WinstOrdinalDictionary
    if ($Context.PkgDir) {
        $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
        if ($cacheRead.Error -and -not $result.Warning) { $result.Warning = $cacheRead.Error }
        $cacheIndex = $cacheRead.Index
    }
    $result.CacheIndex = $cacheIndex

    $result.CacheDirById = Get-WinstPackageDirectoryMap -PkgDir $Context.PkgDir
    $result.Ok = $true
    return $result
}
