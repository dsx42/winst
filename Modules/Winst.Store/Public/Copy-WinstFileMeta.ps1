#Requires -Version 5.1

function Copy-WinstFileMeta {
    <#
    .SYNOPSIS
        把索引条目里的记账（fileMeta）复制成可写的记账表。
    .OUTPUTS
        新的记账表（文件名 → 元信息）；来源为空或结构对不上时返回空表。
    #>
    param($FileMeta)

    $table = New-WinstOrdinalDictionary
    foreach ($pair in @(Get-WinstEntryPairs -Entry $FileMeta)) {
        $name = [string]$pair[0]
        $item = $pair[1]
        if (-not $name -or $null -eq $item) { continue }
        $table[$name] = New-WinstFileMetaEntry `
            -Url ([string](Get-EntryValue -Entry $item -Key 'url' -Default '')) `
            -SourceVersion ([string](Get-EntryValue -Entry $item -Key 'sourceVersion' -Default '')) `
            -ETag ([string](Get-EntryValue -Entry $item -Key 'etag' -Default '')) `
            -LastModified ([string](Get-EntryValue -Entry $item -Key 'lastModified' -Default '')) `
            -Size (Get-EntryValue -Entry $item -Key 'size' -Default $null) `
            -DownloadedAt (Get-EntryString -Entry $item -Key 'downloadedAt') `
            -LastCheckedAt (Get-EntryString -Entry $item -Key 'lastCheckedAt') `
            -ExpectedHash (Get-EntryString -Entry $item -Key 'expectedHash') `
            -ExpectedAlgorithm (Get-EntryString -Entry $item -Key 'expectedAlgorithm') `
            -ChecksumHashFile (Get-EntryString -Entry $item -Key 'checksumHashFile') `
            -ChecksumHashFrom (Get-EntryString -Entry $item -Key 'checksumHashFrom') `
            -ChecksumFingerprint (Get-EntryString -Entry $item -Key 'checksumFingerprint')
    }
    return $table
}
