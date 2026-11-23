#Requires -Version 5.1

function Get-WinstPackageFileHash {
    <#
    .SYNOPSIS
        补算缺少的包摘要，同一文件戳下的解析、规划和索引写回复用计算结果。
    #>
    param([string]$Path, [string]$Algorithm = 'SHA256', [ref]$IndexHash)

    $stamp = Get-WinstFileStamp -Path $Path
    if (-not $stamp) { return '' }
    $cache = Get-WinstState -Name WinstPackageHashCache
    $hashes = $cache[$Path]
    if (-not $hashes -or $hashes.Stamp -cne $Stamp) {
        $hashes = @{ Stamp = $Stamp }
        $cache[$Path] = $hashes
    }
    if ($null -ne $IndexHash -and $IndexHash.Value) { $hashes['SHA256'] = $IndexHash.Value }
    if (-not $hashes[$Algorithm]) {
        if ($hashes['SHA256']) {
            $hashes[$Algorithm] = Get-WinstFileHash -Path $Path -Algorithm $Algorithm
        } else {
            $sha256 = ''
            $hashes[$Algorithm] = Get-WinstFileHash -Path $Path -Algorithm $Algorithm -IndexHash ([ref]$sha256)
            $hashes['SHA256'] = $sha256
        }
    }
    if ($null -ne $IndexHash) { $IndexHash.Value = $hashes['SHA256'] }
    return [string]$hashes[$Algorithm]
}
