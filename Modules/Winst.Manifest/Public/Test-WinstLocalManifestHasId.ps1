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
        [Parameter(Mandatory = $true)][string]$Id,
        [hashtable]$Lookup = @{}
    )

    $pkgDir = ''
    if ($Context) { $pkgDir = [string]$Context['PkgDir'] }
    if (-not $Lookup.ContainsKey('Files')) {
        $Lookup.Files = @(Get-LocalManifestFiles -PkgDir $pkgDir)
        $Lookup.Sets = New-WinstOrdinalDictionary
    }
    foreach ($path in $Lookup.Files) {
        if ($Lookup.Sets.Contains($path)) {
            if ($Lookup.Sets[$path].Contains($Id)) { return $true }
            continue
        }
        try {
            $read = Read-WinstJsonFileCached -ParsedOnly -Path $path
            if (-not $read.Ok) { throw $read.Error }
            if ($read.Empty) { throw '清单内容为空' }
            $entries = @(Get-ManifestEntries -Manifest $read.Value)
        } catch {
            throw ('读取本地清单失败（{0}）：{1}' -f $path, $_.Exception.Message)
        }
        $ids = New-WinstOrdinalDictionary
        foreach ($entry in $entries) { $ids[(Get-EntryString -Entry $entry -Key 'id')] = $true }
        $Lookup.Sets[$path] = $ids
        if ($ids.Contains($Id)) { return $true }
    }
    return $false
}
