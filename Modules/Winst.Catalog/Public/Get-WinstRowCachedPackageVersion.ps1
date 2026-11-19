#Requires -Version 5.1

function Get-WinstRowCachedPackageVersion {
    <#
    .SYNOPSIS
        取一行（versionFromPackage 条目）「已下载安装包」的版本号：取不到返回空串。
    .DESCRIPTION
        优先用解析锁里的 version（解析时已从缓存里那份包的文件信息 / 缓存索引取得，带 versionFromCache
        标记）；解析锁里没有时再读缓存索引——下载完成时从包内文件信息确认的
        版本号写在那里。两者都只代表「缓存里那份」，不代表软件源当前提供的那一份。
    #>
    param(
        [string]$PkgDir,
        $Row,
        $Chosen = (Get-WinstRowBestPlanEntry -Row $Row)
    )

    if (-not $Chosen -or -not (Get-EntryBool -Entry $Chosen['Plan'] -Key 'versionFromPackage')) { return '' }
    $version = (Get-EntryString -Entry $Chosen['Plan'] -Key 'version').Trim()
    if ($version) { return $version }
    if (-not $PkgDir) { return '' }
    $id = [string](Get-EntryString -Entry $Row -Key 'Id')
    if (-not $id) { return '' }
    $download = Get-EntryValue -Entry $chosen['Plan'] -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) { return '' }
    $name = Get-EntryString -Entry $files[0] -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url (Get-EntryString -Entry $files[0] -Key 'url') }
    if (-not $name) { return '' }
    $indexRead = Read-WinstCacheIndex -PkgDir $PkgDir -Ids @($id)
    if (-not $indexRead -or [string]$indexRead.Error -or -not $indexRead.Index.Contains($id)) { return '' }
    $cached = $indexRead.Index[$id]
    $meta = Get-WinstFileMeta -Entry $cached -FileName $name
    if (-not $meta.Url -or $meta.Url -cne (Get-EntryString -Entry $files[0] -Key 'url')) { return '' }
    return ([string](Get-EntryString -Entry $cached -Key 'version')).Trim()
}
