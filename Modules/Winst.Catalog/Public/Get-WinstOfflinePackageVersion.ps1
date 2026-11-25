#Requires -Version 5.1

function Get-WinstOfflinePackageVersion {
    <#
    .SYNOPSIS
        离线计划可复用主包时返回索引登记的版本。
    #>
    param([hashtable]$Context, $Plan, $CacheIndex, $FilePlans)

    $id = Get-EntryString -Entry $Plan -Key 'id'
    if ($null -eq $CacheIndex) { $CacheIndex = (Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($id)).Index }
    if ($null -eq $FilePlans) {
        $files = @(Get-EntryArray -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files')
        $FilePlans = @(Get-WinstPackageFilePlans -Context $Context -Id $id -Files $files -Index $CacheIndex -ManifestOrigin (Get-EntryString -Entry $Plan -Key 'manifestOrigin') -Offline)
    }
    if (-not $FilePlans.Count) { return '' }
    if ($FilePlans[0].NeedDownload) { return '' }
    return Get-EntryString -Entry $CacheIndex[$id] -Key 'version'
}
