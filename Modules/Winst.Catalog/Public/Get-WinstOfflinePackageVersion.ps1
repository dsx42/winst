#Requires -Version 5.1

function Get-WinstOfflinePackageVersion {
    <#
    .SYNOPSIS
        按选定计划的主包与取版文件读取本地缓存版本。
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
    if (-not (Get-EntryBool -Entry $plan -Key 'versionFromPackage')) { return [string]$FilePlans[0].CachedVersion }

    $versionInput = Get-WinstPackageVersionInput -Plan $plan
    if (-not $versionInput -or $FilePlans[$versionInput.Index].NeedDownload) { return '' }
    $cached = Get-WinstCachedPackageVersion -Context $Context -MainFilePlan $FilePlans[0] -Plan $plan -Entry $CacheIndex[$Id] -Offline
    if ($cached) { return $cached }
    $read = Get-WinstPackageDerivedVersion -Context $Context -PkgDir (Join-WinstPath $Context.PkgDir $Id) -Plan $plan -FileName $versionInput.Name
    if ($read.Ok) { return $read.Version }
    return ''
}
