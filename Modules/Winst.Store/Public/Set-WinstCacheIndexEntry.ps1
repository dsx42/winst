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

    # 防御：同一字典不允许同时存在仅大小写不同的键——这种 JSON 在 PS 5.1 / 7 下都无法被
    # ConvertFrom-Json 解析（会整份索引判为损坏并重建，全部版本 / 摘要 / 新鲜度基线一起丢）。
    # 与 Set-WinstInstalledApp 的口径一致：写入前先移除仅大小写不同的旧键。
    $collisions = @()
    foreach ($key in @($Index.Keys)) {
        $keyText = [string]$key
        if ($keyText -cne $Id -and $keyText -ieq $Id) { $collisions += $keyText }
    }
    foreach ($key in $collisions) { $Index.Remove($key) }

    $Index[$Id] = [ordered]@{
        version        = $Version
        files          = @($Files)
        hashes         = $Hashes
        manifestHashes = $ManifestHashes
        fileMeta       = $FileMeta
        downloadedAt   = $DownloadedAt
    }
}
