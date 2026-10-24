#Requires -Version 5.1

function Get-WinstRowCachedPackageVersion {
    <#
    .SYNOPSIS
        取一行（versionFromPackage 条目）「已下载安装包」的版本号：取不到返回空串。
    .DESCRIPTION
        优先用解析锁里的 version（解析时已从缓存里那份包的文件信息 / 缓存索引取得，带 versionFromCache
        标记，见 New-ResolvedAppPlan）；解析锁里没有时再读缓存索引——下载完成时从包内文件信息确认的
        版本号写在那里。两者都只代表「缓存里那份」，不代表软件源当前提供的那一份。
    #>
    param(
        [string]$PkgDir,
        $Row
    )

    $chosen = Get-WinstRowBestPlanEntry -Row $Row
    if ($chosen -and $chosen['Plan']) {
        if ((Get-EntryBool -Entry $chosen['Plan'] -Key 'versionFromPackage') -and
            (Get-EntryBool -Entry $chosen['Plan'] -Key 'versionFromCache')) {
            $version = ([string](Get-EntryString -Entry $chosen['Plan'] -Key 'version')).Trim()
            if ($version) { return $version }
        }
    }
    if (-not $PkgDir) { return '' }
    $id = [string](Get-EntryString -Entry $Row -Key 'Id')
    if (-not $id) { return '' }
    $indexRead = Read-WinstCacheIndex -PkgDir $PkgDir
    if (-not $indexRead -or [string]$indexRead.Error -or -not $indexRead.Index.Contains($id)) { return '' }
    return ([string](Get-EntryString -Entry $indexRead.Index[$id] -Key 'version')).Trim()
}
