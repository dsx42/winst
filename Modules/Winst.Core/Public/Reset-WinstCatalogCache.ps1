#Requires -Version 5.1

function Reset-WinstCatalogCache {
    <#
    .SYNOPSIS
        失效软件清单汇总缓存（软件源刷新 / 增删 / 本地清单变动后调用）。

    .DESCRIPTION
        移除软件汇总、搜索目录与依赖索引缓存，下次读取时分别重建。
    #>
    Remove-WinstState -Name WinstAllAppsCache
    Remove-WinstState -Name WinstSearchCatalogCache
    Remove-WinstState -Name WinstDependencyIndex
}
