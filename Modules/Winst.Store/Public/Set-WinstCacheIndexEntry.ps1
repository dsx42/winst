#Requires -Version 5.1

function Set-WinstCacheIndexEntry {
    <#
    .SYNOPSIS
        写入 / 覆盖某 id 的缓存索引条目。
    .DESCRIPTION
        ManifestHashes 记录各包文件「按软件源声明算法」的摘要（形如 文件名 → { sha512 = <摘要> }）：
        软件源声明的不是 sha256 时（如 Maven 只用 .sha512），下次命中判定可直接比对这份摘要，
        不必为判断缓存是否可用而重算整包哈希。
        FileMeta 记录每个文件的实际地址 / 本次版本 / 校验器基线 / 大小与时间，
        供文件级新鲜度判定（files[].refresh）使用。
        downloadedAt 随主包下载更新，旧索引缺少逐文件时间时沿用条目时间。
    #>
    param(
        [Parameter(Mandatory = $true)]$Index,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Version,
        [string]$BundleSource,
        [string[]]$Files,
        $Hashes,
        $ManifestHashes,
        $FileMeta,
        [string]$DownloadedAt = ''
    )

    if (-not $DownloadedAt) {
        if ($Files.Count) {
            $mainMeta = Get-WinstFileMeta -Entry @{ fileMeta = $FileMeta } -FileName $Files[0]
            $DownloadedAt = [string]$mainMeta.DownloadedAt
        }
        if (-not $DownloadedAt -and $Index.Contains($Id)) {
            $DownloadedAt = Get-EntryString -Entry $Index[$Id] -Key 'downloadedAt'
        }
    }
    if ($null -eq $Hashes) { $Hashes = New-WinstOrdinalDictionary -IgnoreCase }
    if ($null -eq $ManifestHashes) { $ManifestHashes = New-WinstOrdinalDictionary -IgnoreCase }
    if ($null -eq $FileMeta) { $FileMeta = New-WinstOrdinalDictionary -IgnoreCase }

    Assert-WinstDistinctIds -Ids @(@($Index.Keys) + @($Id))

    $Index[$Id] = [ordered]@{
        version        = $Version
        files          = @($Files)
        hashes         = $Hashes
        manifestHashes = $ManifestHashes
        fileMeta       = $FileMeta
        downloadedAt   = $DownloadedAt
    }
    if ($BundleSource) { $Index[$Id]['bundleSource'] = $BundleSource }
}
