#Requires -Version 5.1

function ConvertTo-WinstCacheIndexEntry {
    <#
    .SYNOPSIS
        把索引文件里的一条记录（JSON 对象）转成内存索引条目。
    .OUTPUTS
        [ordered]@{ version; files; hashes; manifestHashes; fileMeta; downloadedAt }
    #>
    param($Entry)

    $version = Get-EntryString -Entry $Entry -Key 'version'
    $downloadedAt = Get-EntryString -Entry $Entry -Key 'downloadedAt'
    $files = New-Object 'System.Collections.Generic.List[string]'
    foreach ($f in @(Get-EntryArray -Entry $Entry -Key 'files')) {
        $text = [string]$f
        if ($text.Trim()) { $files.Add($text) }
    }
    # 每个包文件的 sha256
    $hashes = New-WinstOrdinalDictionary -IgnoreCase
    $hashObj = Get-EntryValue -Entry $Entry -Key 'hashes' -Default $null
    if ($null -ne $hashObj) {
        if ($hashObj -is [System.Collections.IDictionary]) {
            foreach ($key in @($hashObj.Keys)) {
                $value = [string]$hashObj[$key]
                if ($key -and $value) { $hashes[[string]$key] = $value.ToLowerInvariant() }
            }
        } else {
            foreach ($hp in $hashObj.PSObject.Properties) {
                if ($hp.Name -and $hp.Value) { $hashes[$hp.Name] = ([string]$hp.Value).ToLowerInvariant() }
            }
        }
    }
    # 每个包文件「按软件源声明算法」的摘要（如 Maven 的 sha512；软件源声明非 sha256 时用它免去重算）
    # 读自 JSON 时嵌套对象是 PSCustomObject（不是 IDictionary），两种形态都要认
    $manifestHashes = New-WinstOrdinalDictionary -IgnoreCase
    $manifestObj = Get-EntryValue -Entry $Entry -Key 'manifestHashes' -Default $null
    if ($null -ne $manifestObj) {
        foreach ($pair in @(Get-WinstEntryPairs -Entry $manifestObj)) {
            $fileKey = [string]$pair[0]
            $perFile = $pair[1]
            if (-not $fileKey -or $null -eq $perFile) { continue }
            $algorithms = New-WinstOrdinalDictionary -IgnoreCase
            foreach ($innerPair in @(Get-WinstEntryPairs -Entry $perFile)) {
                $algorithmKey = [string]$innerPair[0]
                $value = [string]$innerPair[1]
                if ($algorithmKey -and $value) { $algorithms[$algorithmKey.ToLowerInvariant()] = $value.ToLowerInvariant() }
            }
            if ($algorithms.Count -gt 0) { $manifestHashes[$fileKey] = $algorithms }
        }
    }
    # 每个文件的记账：
    # 旧索引没有该字段时留空（首次用到时再建立基线），不报错、不误判
    $fileMeta = Copy-WinstFileMeta -FileMeta (Get-EntryValue -Entry $Entry -Key 'fileMeta' -Default $null)

    return [ordered]@{
        version        = $version
        files          = $files.ToArray()
        hashes         = $hashes
        manifestHashes = $manifestHashes
        fileMeta       = $fileMeta
        downloadedAt   = $downloadedAt
    }
}
