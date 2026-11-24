#Requires -Version 5.1

function Set-WinstManifestHash {
    <#
    .SYNOPSIS
        把某包文件「按软件源声明算法」的摘要写进索引用的容器（形如 { 文件名 = { sha512 = <摘要> } }）。
    #>
    param($Container, [string]$FileName, [string]$Algorithm, [string]$Hash)

    if ($null -eq $Container -or ($Container -isnot [System.Collections.IDictionary])) { return }
    if (-not $FileName) { return }

    $text = $Hash.Trim()
    $algorithmKey = $Algorithm.Trim().ToLowerInvariant()
    if (-not $text -or -not $algorithmKey) { return }

    $key = Get-WinstFileMapKey -Map $Container -Name $FileName
    $entry = $Container[$key]
    if ($null -eq $entry) {
        $entry = New-WinstOrdinalDictionary -IgnoreCase
        $Container[$key] = $entry
    }
    if ($entry -is [System.Collections.IDictionary]) { $entry[$algorithmKey] = $text.ToLowerInvariant() }
}
