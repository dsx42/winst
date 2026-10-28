#Requires -Version 5.1

function Test-WinstLocalManifestHasId {
    <#
    .SYNOPSIS
        判断某个 id 是否出现在本地清单文件里（脚本同目录 manifest.json / manifests\*.json、
        安装包位置 manifests\*.json，见 Get-LocalManifestFiles）。
    .DESCRIPTION
        按需刷新（Update-WinstStaleSources -OnlyIds）默认只解析「sidecar 解析锁里已有记录」的软件——
        缓存里没有的 id 视为不属于本源。这个口径对远程源成立（要联网拉清单才知道 id 归属），但对本地
        清单是误伤：清单文件就在手边，读一下（纯本地 IO，零网络）就能确认归属，确认在册就该解析并
        把解析锁写回 sidecar。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id
    )

    if (-not $Id) { return $false }
    $pkgDir = ''
    if ($Context) { $pkgDir = [string]$Context['PkgDir'] }
    foreach ($path in @(Get-LocalManifestFiles -PkgDir $pkgDir)) {
        $obj = $null
        try {
            $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            if ($raw) { $obj = $raw | ConvertFrom-Json }
        } catch {
            continue
        }
        if ($null -eq $obj) { continue }
        foreach ($entry in @(Get-ManifestEntries -Manifest $obj)) {
            # id 一律 Ordinal：与台账 / 缓存索引的 New-WinstOrdinalDictionary 保持同一口径
            if ((Get-EntryString -Entry $entry -Key 'id') -ceq $Id) { return $true }
        }
    }
    return $false
}
