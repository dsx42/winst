#Requires -Version 5.1

function Read-WinstSourceManifestBody {
    <#
    .SYNOPSIS
        读取本地或远程缓存清单正文，统一 JSON 缓存并区分缺失、空白及错误。
    .OUTPUTS
        @{ Entries; Error; Missing; Empty }
    #>
    param([hashtable]$Context, $Source)

    $result = @{ Entries = @(); Error = ''; Missing = $false; Empty = $false }
    if (Get-EntryBool -Entry $Source -Key 'isLocal') {
        $bundle = Read-LocalManifestBundle -Context $Context -Source $Source
        $result.Entries = @($bundle.Entries)
        $result.Error = [string]$bundle.Error
        return $result
    }
    $name = Get-EntryString -Entry $Source -Key 'name'
    if (-not $name) { $result.Missing = $true; return $result }
    $path = Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $name
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $result.Missing = $true
        return $result
    }
    $read = Read-WinstJsonFileCached -Path $path
    if (-not $read.Ok) { $result.Error = [string]$read.Error; return $result }
    if (-not ([string]$read.Raw).Trim()) { $result.Empty = $true; return $result }
    $result.Entries = @(Get-ManifestEntries -Manifest $read.Value)
    return $result
}
