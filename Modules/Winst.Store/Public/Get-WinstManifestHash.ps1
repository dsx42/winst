#Requires -Version 5.1

function Get-WinstManifestHash {
    <#
    .SYNOPSIS
        从索引条目里取某个包文件按指定算法记录的「软件源声明摘要」；没有返回空串。
    .DESCRIPTION
        索引里的 manifestHashes 形如 { 文件名 = { sha512 = <摘要>; sha1 = <摘要> } }；
        结构对不上（旧索引没有该字段）时返回空串，调用方退回现算。
    #>
    param($Entry, [string]$FileName, [string]$Algorithm)

    if ($null -eq $Entry -or -not $FileName) { return '' }
    $algorithmKey = ''
    if ($null -ne $Algorithm) { $algorithmKey = ([string]$Algorithm).Trim() }
    if (-not $algorithmKey) { return '' }

    $map = Get-EntryValue -Entry $Entry -Key 'manifestHashes' -Default $null
    if ($null -eq $map) { return '' }
    if ($map -isnot [System.Collections.IDictionary]) { return '' }

    $fileHashes = $null
    foreach ($key in @($map.Keys)) {
        if ([string]$key -ieq $FileName) { $fileHashes = $map[$key]; break }
    }
    if ($null -eq $fileHashes) { return '' }
    if ($fileHashes -isnot [System.Collections.IDictionary]) { return '' }

    foreach ($key in @($fileHashes.Keys)) {
        if ([string]$key -ieq $algorithmKey) { return ([string]$fileHashes[$key]).ToLowerInvariant() }
    }
    return ''
}
