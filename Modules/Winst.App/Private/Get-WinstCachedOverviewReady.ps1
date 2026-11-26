#Requires -Version 5.1

function Get-WinstCachedOverviewReady {
    <#
    .SYNOPSIS
        已下载包页面的公共前置：按实际安装包目录确定展示项 → 按需刷新版本 → 重建总览。
    .DESCRIPTION
        菜单页（Get-WinstCachedListItems）与 CLI（winst list --cached）共用同一段准备逻辑：
        只刷新有正式包或下载暂存目录的 id，随后读取缓存索引补齐版本信息；
        没有已下载包时零解析。

        只准备数据，不打印页面：错误文案、空列表提示与「按回车返回」由调用方决定。
    .OUTPUTS
        @{ Ok; Error; Warning; Items }
    #>
    param([hashtable]$Context)

    $packageDirs = Get-WinstPackageDirectoryMap -PkgDir $Context.PkgDir -IncludeDownloadStage
    $displayIds = @($packageDirs.Keys)
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $displayIds
    Write-WinstRefreshErrors -Errors $refresh.Errors

    return (Get-WinstCachedOverview -Context $Context -PackageDirs $packageDirs)
}
