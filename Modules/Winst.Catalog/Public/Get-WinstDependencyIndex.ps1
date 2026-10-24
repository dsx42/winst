#Requires -Version 5.1

function Get-WinstDependencyIndex {
    <#
    .SYNOPSIS
        依赖关系索引（id → 依赖 id 列表、id → 软件清单行），进程内只构建一次。
    .DESCRIPTION
        依赖来自各软件源解析锁里条目的 dependencies 字段（经 Get-WinstSearchCatalog 汇总；
        同一 id 多来源时取并集、按 Ordinal 去重）。索引在进程内缓存，软件源刷新后置空重建
        （见 Update-ManifestSource / Remove-RemoteManifest）。
    .OUTPUTS
        @{ Deps = <ordinal 字典: id → @(依赖 id)>; Rows = <ordinal 字典: id → 软件清单行> }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    if ($null -ne (Get-WinstState -Name WinstDependencyIndex)) { return (Get-WinstState -Name WinstDependencyIndex) }

    $deps = New-WinstOrdinalDictionary
    $rows = New-WinstOrdinalDictionary
    foreach ($row in @(Get-WinstSearchCatalog -Context $Context)) {
        $id = [string]$row['Id']
        if (-not $id) { continue }
        if (-not $rows.Contains($id)) { $rows[$id] = $row }

        $seen = New-WinstOrdinalDictionary
        $list = New-Object 'System.Collections.Generic.List[string]'
        foreach ($sourceEntry in @($row['Sources'])) {
            foreach ($depItem in @(Get-EntryArray -Entry $sourceEntry['Plan'] -Key 'dependencies')) {
                if ($null -eq $depItem) { continue }
                $depId = ([string]$depItem).Trim()
                if (-not $depId) { continue }
                if ($seen.Contains($depId)) { continue }
                $seen[$depId] = $true
                $list.Add($depId)
            }
        }
        $deps[$id] = @($list.ToArray())
    }

    $null = Set-WinstState -Name WinstDependencyIndex -Value (@{ Deps = $deps; Rows = $rows })
    return (Get-WinstState -Name WinstDependencyIndex)
}
