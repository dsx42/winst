#Requires -Version 5.1

function Get-WinstFileMeta {
    <#
    .SYNOPSIS
        取某个文件的记账（索引条目里的 fileMeta，文件名大小写不敏感比较）；没有时返回全空结构。
    .OUTPUTS
        @{ Url; SourceVersion; ETag; LastModified; Size; DownloadedAt; LastCheckedAt;
           ExpectedHash; ExpectedAlgorithm; ChecksumHashFile; ChecksumHashFrom; ChecksumFingerprint; Exists }
    #>
    param($Entry, [string]$FileName)

    $result = @{
        Url           = ''
        SourceVersion = ''
        ETag          = ''
        LastModified  = ''
        Size          = $null
        DownloadedAt  = ''
        LastCheckedAt = ''
        ExpectedHash = ''
        ExpectedAlgorithm = ''
        ChecksumHashFile = ''
        ChecksumHashFrom = ''
        ChecksumFingerprint = ''
        Exists        = $false
    }
    if ($null -eq $Entry -or -not $FileName) { return $result }

    $map = Get-EntryValue -Entry $Entry -Key 'fileMeta' -Default $null
    if ($null -eq $map -or ($map -isnot [System.Collections.IDictionary])) { return $result }

    $item = $null
    foreach ($key in @($map.Keys)) {
        if ([string]$key -ieq $FileName) { $item = $map[$key]; break }
    }
    if ($null -eq $item) { return $result }

    $result.Exists = $true
    $result.Url = [string](Get-EntryValue -Entry $item -Key 'url' -Default '')
    $result.SourceVersion = [string](Get-EntryValue -Entry $item -Key 'sourceVersion' -Default '')
    $result.ETag = [string](Get-EntryValue -Entry $item -Key 'etag' -Default '')
    $result.LastModified = [string](Get-EntryValue -Entry $item -Key 'lastModified' -Default '')
    $size = Get-EntryValue -Entry $item -Key 'size' -Default $null
    if ($null -ne $size) { $result.Size = $size }
    # 时间字段走 Get-EntryString：ConvertFrom-Json 会把 ISO 形状的字符串转成 DateTime，
    # 直接 [string] 强转会变成随区域设置变化的本地格式（见 13）
    $result.DownloadedAt = Get-EntryString -Entry $item -Key 'downloadedAt'
    $result.LastCheckedAt = Get-EntryString -Entry $item -Key 'lastCheckedAt'
    $result.ExpectedHash = (Get-EntryString -Entry $item -Key 'expectedHash').ToLowerInvariant()
    $result.ExpectedAlgorithm = (Get-EntryString -Entry $item -Key 'expectedAlgorithm').ToUpperInvariant()
    $result.ChecksumHashFile = Get-EntryString -Entry $item -Key 'checksumHashFile'
    $result.ChecksumHashFrom = Get-EntryString -Entry $item -Key 'checksumHashFrom'
    $result.ChecksumFingerprint = (Get-EntryString -Entry $item -Key 'checksumFingerprint').ToLowerInvariant()
    return $result
}
