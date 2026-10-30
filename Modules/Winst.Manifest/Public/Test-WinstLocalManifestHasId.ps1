#Requires -Version 5.1

function Test-WinstLocalManifestHasId {
    <#
    .SYNOPSIS
        判断某个 id 是否出现在本地清单文件里（脚本同目录 manifest.json / manifests\*.json、
        安装包位置 manifests\*.json，见 Get-LocalManifestFiles）。
    .DESCRIPTION
        解析锁可能只覆盖部分软件；本函数读取清单正文确认未解析条目的归属，不联网。
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
