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
        供 8.4 的文件级新鲜度判定（files[].refresh）使用。
    #>
    param(
        [Parameter(Mandatory = $true)]$Index,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Version = '',
        [string[]]$Files = @(),
        $Hashes = $null,
        $ManifestHashes = $null,
        $FileMeta = $null,
        [string]$DownloadedAt = ''
    )

    if (-not $DownloadedAt) { $DownloadedAt = (Get-Date).ToString('s') }
    if ($null -eq $Hashes) { $Hashes = New-WinstOrdinalDictionary }
    if ($null -eq $ManifestHashes) { $ManifestHashes = New-WinstOrdinalDictionary }
    if ($null -eq $FileMeta) { $FileMeta = New-WinstOrdinalDictionary }
    $Index[$Id] = [ordered]@{
        version        = $Version
        files          = @($Files)
        hashes         = $Hashes
        manifestHashes = $ManifestHashes
        fileMeta       = $FileMeta
        downloadedAt   = $DownloadedAt
    }
}
