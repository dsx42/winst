#Requires -Version 5.1

function Get-WinstInstalledOverview {
    <#
    .SYNOPSIS
        读取安装记录并合入软件清单版本，产出「已装软件」视图（列表 / 详情 / 更新 / CLI 共用）。
    .DESCRIPTION
        一次读安装记录 + 一次构建软件清单视图；软件清单版本来自已解析的软件清单缓存，
        **不逐条发网络请求**（`--offline` 下完全离线可用）。软件源的刷新由调用方决定：
        各页面与 CLI 进入前调用 `Update-WinstStaleSources`（按有效期），
        菜单「检查更新」额外用 `-Force` 强制刷新全部软件源。
    .OUTPUTS
        @{ Ok; Error; Warning; Items; State; RowById; CacheIndex }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Ids = @()
    )

    $result = @{ Ok = $false; Error = ''; Warning = ''; Items = @(); State = $null; RowById = $null; CacheIndex = $null }

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        $result.Error = $stateRead.Error
        return $result
    }
    $result.Warning = $stateRead.Error
    $result.State = $stateRead.State

    $rowById = Get-WinstCatalogRowMap -Context $Context
    $result.RowById = $rowById

    # 已下载的安装包（缓存索引读一次，供各条目共用；缺失 / 损坏时会按目录重建）
    $cacheIndex = $null
    if ($Context.PkgDir) {
        try { $cacheIndex = (Read-WinstCacheIndex -PkgDir $Context.PkgDir).Index } catch { $cacheIndex = $null }
    }
    $result.CacheIndex = $cacheIndex

    $filter = $null
    if (@($Ids).Count -gt 0) {
        $filter = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal)
        foreach ($one in @($Ids)) {
            $text = [string]$one
            if ($text) { $filter[$text] = $true }
        }
    }

    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($key in @($stateRead.State['Installed'].Keys)) {
        $idText = [string]$key
        if ($filter -and -not $filter.ContainsKey($idText)) { continue }
        $entry = Get-WinstInstalledApp -State $stateRead.State -Id $idText
        if (-not $entry) { continue }
        $row = $null
        if ($rowById.Contains($idText)) { $row = $rowById[$idText] }
        $items.Add((New-WinstInstalledItem -Context $Context -Id $idText -Entry $entry -Row $row -CacheIndex $cacheIndex))
    }

    # 用 @() 包住函数调用：PowerShell 里「函数返回空数组」到调用方会变成 $null，
    # 而调用方普遍写 `@($overview.Items)` —— $null 会变成「1 个 $null 条目」，
    # 于是空列表页会显示「共 1 个…」并在渲染时抛「Cannot index into a null array」。
    $result.Items = @(Sort-WinstRowsByGroup -Rows $items -ByName)
    $result.Ok = $true
    return $result
}
