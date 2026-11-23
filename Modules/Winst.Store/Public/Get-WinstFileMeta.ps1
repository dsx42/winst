#Requires -Version 5.1

function Get-WinstFileMeta {
    <#
    .SYNOPSIS
        取某个文件的记账（索引条目里的 fileMeta，文件名大小写不敏感比较）；没有时返回全空结构。
    .OUTPUTS
        @{ Url; ManifestOrigin; SourceVersion; ETag; LastModified; Size; DownloadedAt; LastCheckedAt;
           ExpectedHash; ExpectedAlgorithm; ChecksumHashFile; ChecksumHashFrom; ChecksumFingerprint; Exists }
    #>
    param($Entry, [string]$FileName)

    $map = Get-EntryValue -Entry $Entry -Key 'fileMeta'
    $item = $null
    if ($FileName -and $map -is [System.Collections.IDictionary]) {
        $item = $map[(Get-WinstFileMapKey -Map $map -Name $FileName)]
    }

    $meta = New-WinstFileMetaEntry -Item $item -NormalizeDigest
    $result = @{ Exists = $null -ne $item }
    # 公开读接口使用 PascalCase，磁盘索引使用小写开头的字段名。
    foreach ($name in @('Url', 'ManifestOrigin', 'SourceVersion', 'ETag', 'LastModified', 'Size', 'DownloadedAt', 'LastCheckedAt',
            'ExpectedHash', 'ExpectedAlgorithm', 'ChecksumHashFile', 'ChecksumHashFrom', 'ChecksumFingerprint')) {
        $result[$name] = $meta[$name]
    }
    return $result
}
