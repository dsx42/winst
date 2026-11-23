#Requires -Version 5.1

function Invoke-WinstEngineDownload {
    <#
    .SYNOPSIS
        ① 引擎自动引导下载（直接 HTTP）：逐文件下载 + 校验 + 写缓存索引 + 清理旧包。
    .OUTPUTS
        成功时返回 Ok、PrimaryPath，失败时返回 Ok、Error。
    #>
    param([hashtable]$Context, [string]$Id, $Plan, [string]$PlanId, [switch]$Quiet)

    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) {
        return @{ Ok = $false; Error = ('{0} 的软件定义里没有可下载的文件' -f $Id) }
    }

    $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($PlanId)
    $index = $indexRead.Index
    $previousEntry = $null
    if ($index.Contains($PlanId)) { $previousEntry = $index[$PlanId] }

    # 缓存里已有需要的包（且校验码一致 / 新鲜度判定命中）就跳过下载，不重复下载
    $plans = @(Get-WinstPackageFilePlans -Context $Context -Index $index -Id $PlanId -ManifestOrigin (Get-EntryString -Entry $Plan -Key 'manifestOrigin') -Files $files)
    $pkgDir = Join-WinstPath $Context.PkgDir $PlanId
    $version = Get-EntryString -Entry $Plan -Key 'version'
    $sourceName = Get-EntryString -Entry $Plan -Key 'manifestOrigin'
    $download = Invoke-WinstPackageDownloadLoop -Context $Context -Plans $plans -PkgDir $pkgDir -Id $PlanId -DisplayName $Id `
        -SourceName $sourceName -Version $version -PrevEntry $previousEntry -DirectHttp -Quiet:$Quiet
    if (-not $download.Ok) { return $download }

    Update-WinstPackageCacheIndex -Context $Context -Id $PlanId -Plans $plans -PrevEntry $previousEntry `
        -Version $version -DownloadedNames $download.Names
    Remove-WinstObsoletePackages -Context $Context -Id $PlanId -Plans $plans -DownloadedAny ([bool]$download.Any)

    return @{ Ok = $true; PrimaryPath = $plans[0]['Target'] }
}
