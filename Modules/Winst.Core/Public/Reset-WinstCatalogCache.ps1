#Requires -Version 5.1

function Reset-WinstCatalogCache {
    <#
    .SYNOPSIS
        失效软件清单汇总缓存（软件源刷新 / 增删 / 本地清单变动后调用）。

    .DESCRIPTION
        用 Remove-WinstState 真正移除条目，而不是写入 $null：缓存的有效性由
        Test-WinstState 判断，写 $null 仍然算「设置过」，会让空结果被当成命中。
        三个缓存各自被调用方按需重建。
    #>
    $null = Remove-WinstState -Name WinstAllAppsCache
    $null = Remove-WinstState -Name WinstSearchCatalogCache
    $null = Remove-WinstState -Name WinstDependencyIndex
}
