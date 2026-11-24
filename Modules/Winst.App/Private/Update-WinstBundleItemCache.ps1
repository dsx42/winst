#Requires -Version 5.1

function Update-WinstBundleItemCache {
    <#
    .SYNOPSIS
        按选定计划检查套件必需文件与声明摘要，更新可复制文件列表；不联网、不写盘。
    #>
    param([hashtable]$Context, $Item, $Lookup)

    $Item['CacheHas'] = $false
    $chosen = $Item['PlanEntry']
    if (-not $chosen) { $Item['CacheError'] = '没有可用的下载计划'; return }
    try {
        $download = Get-EntryValue -Entry $chosen['Plan'] -Key 'download'
        $files = @(Get-EntryArray -Entry $download -Key 'files')
        if ($files.Count -eq 0) { throw '下载计划没有必需文件' }
        $plans = @(Get-WinstPackageFilePlans -Context $Context -Index $Lookup.CacheIndex -Id ([string]$Item['Id']) -ManifestOrigin ([string]$chosen['Source']) -Files $files -Offline)
        $names = @()
        foreach ($file in $plans) {
            if ($file['ValidationError']) { throw ([string]$file['ValidationError']) }
            if ($file['NeedDownload']) { throw ('{0}: {1}' -f $file['Name'], $file['Reason']) }
            $names += [string]$file['Name']
        }
        $Item['CacheVersion'] = Get-WinstOfflinePackageVersion -Context $Context -Plan $chosen['Plan'] -CacheIndex $Lookup.CacheIndex -FilePlans $plans
        $Item['CacheFiles'] = @($names)
        $Item['CacheHas'] = $true
    } catch {
        $Item['CacheError'] = $_.Exception.Message
    }
}
