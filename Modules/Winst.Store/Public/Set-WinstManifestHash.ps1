#Requires -Version 5.1

function Set-WinstManifestHash {
    <#
    .SYNOPSIS
        把某包文件「按软件源声明算法」的摘要写进索引用的容器（形如 { 文件名 = { sha512 = <摘要> } }）。
    .OUTPUTS
        写入后的容器；容器不可写或摘要 / 算法为空时原样返回。
    #>
    param($Container, [string]$FileName, [string]$Algorithm, [string]$Hash)

    if ($null -eq $Container -or ($Container -isnot [System.Collections.IDictionary])) { return $Container }
    if (-not $FileName) { return $Container }

    $text = ''
    if ($null -ne $Hash) { $text = ([string]$Hash).Trim() }
    $algorithmKey = ''
    if ($null -ne $Algorithm) { $algorithmKey = ([string]$Algorithm).Trim().ToLowerInvariant() }
    if (-not $text -or -not $algorithmKey) { return $Container }

    $entry = $null
    foreach ($key in @($Container.Keys)) {
        if ([string]$key -ieq $FileName) { $entry = $Container[$key]; break }
    }
    if ($null -eq $entry) {
        $entry = New-WinstOrdinalDictionary
        $Container[$FileName] = $entry
    }
    if ($entry -is [System.Collections.IDictionary]) { $entry[$algorithmKey] = $text.ToLowerInvariant() }
    return $Container
}
