#Requires -Version 5.1

function Get-WinstDependencyIndex {
    <#
    .SYNOPSIS
        依赖关系索引（id → 依赖 id 列表、id → 软件清单行），进程内只构建一次。
    .DESCRIPTION
        依赖来自各软件源解析锁里条目的 dependencies 字段（经 Get-WinstSearchCatalog 汇总；
        每个 id 默认使用最高可用版本的来源，依赖 id 按 Ordinal 去重）。索引在进程内缓存，软件源刷新后置空重建
        （见 Update-ManifestSource / Remove-RemoteManifest）。离线套件可传入索引，按登记来源构建独立视图。
    .OUTPUTS
        @{ Deps = <ordinal 字典: id → @(依赖 id)>; Rows = <ordinal 字典: id → 软件清单行> }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context, $BundleCacheIndex = $null)

    $bundleIndex = Get-EntryValue -Entry $Context -Key 'BundleDependencyIndex'
    if ($null -ne $bundleIndex) { return $bundleIndex }

    $isBundle = $null -ne $BundleCacheIndex
    if (-not $isBundle -and $null -ne (Get-WinstState -Name WinstDependencyIndex)) {
        return (Get-WinstState -Name WinstDependencyIndex)
    }

    $deps = New-WinstOrdinalDictionary
    $rows = New-WinstOrdinalDictionary
    foreach ($row in @(Get-WinstSearchCatalog -Context $Context)) {
        $id = [string]$row['Id']
        if (-not $id) { continue }
        if ($rows.Contains($id)) { continue }
        if ($isBundle -and $BundleCacheIndex.Contains($id)) {
            $cached = $BundleCacheIndex[$id]
            $source = Get-EntryString -Entry $cached -Key 'bundleSource'
            if (-not $source -and (Get-EntryString -Entry $Context -Key 'PkgDirSource') -eq 'script') {
                $files = @(Get-EntryArray -Entry $cached -Key 'files')
                if ($files.Count) { $source = (Get-WinstFileMeta -Entry $cached -FileName $files[0]).ManifestOrigin }
            }
            if ($source) {
                $row = Copy-WinstObjectShallow -InputObject $row
                $row['Sources'] = @($row['Sources'] | Where-Object { $_['Source'] -ceq $source })
            }
        }
        $rows[$id] = $row

        $seen = New-WinstOrdinalDictionary
        $list = New-Object 'System.Collections.Generic.List[string]'
        $sourceEntry = Get-WinstRowBestPlanEntry -Row $row
        if ($sourceEntry) {
            foreach ($depItem in @(Get-EntryArray -Entry $sourceEntry['Plan'] -Key 'dependencies')) {
                if ($null -eq $depItem) { continue }
                $depId = ([string]$depItem).Trim()
                if (-not $depId -or $seen.Contains($depId)) { continue }
                $seen[$depId] = $true
                $list.Add($depId)
            }
        }
        $deps[$id] = @($list.ToArray())
    }

    $result = @{ Deps = $deps; Rows = $rows }
    if (-not $isBundle) { $null = Set-WinstState -Name WinstDependencyIndex -Value $result }
    return $result
}
