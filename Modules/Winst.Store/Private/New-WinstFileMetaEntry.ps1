#Requires -Version 5.1

function New-WinstFileMetaEntry {
    <#
    .SYNOPSIS
        构造一条文件记账。
    #>
    param(
        [string]$Url = '',
        [string]$SourceVersion = '',
        [string]$ETag = '',
        [string]$LastModified = '',
        $Size = $null,
        [string]$DownloadedAt = '',
        [string]$LastCheckedAt = '',
        [string]$ExpectedHash = '',
        [string]$ExpectedAlgorithm = '',
        [string]$ChecksumHashFile = '',
        [string]$ChecksumHashFrom = '',
        [string]$ChecksumFingerprint = ''
    )

    return [ordered]@{
        url                 = $Url
        sourceVersion       = $SourceVersion
        etag                = $ETag
        lastModified        = $LastModified
        size                = $Size
        downloadedAt        = $DownloadedAt
        lastCheckedAt       = $LastCheckedAt
        expectedHash        = $ExpectedHash
        expectedAlgorithm   = $ExpectedAlgorithm
        checksumHashFile    = $ChecksumHashFile
        checksumHashFrom    = $ChecksumHashFrom
        checksumFingerprint = $ChecksumFingerprint
    }
}
