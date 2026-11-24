#Requires -Version 5.1

function New-WinstFileMetaEntry {
    <#
    .SYNOPSIS
        构造一条文件记账。
    #>
    param($Item, [switch]$NormalizeDigest)

    $meta = [ordered]@{
        url                 = [string](Get-EntryValue -Entry $Item -Key 'url')
        manifestOrigin      = Get-EntryString -Entry $Item -Key 'manifestOrigin'
        sourceVersion       = [string](Get-EntryValue -Entry $Item -Key 'sourceVersion')
        etag                = [string](Get-EntryValue -Entry $Item -Key 'etag')
        lastModified        = [string](Get-EntryValue -Entry $Item -Key 'lastModified')
        size                = Get-EntryValue -Entry $Item -Key 'size'
        downloadedAt        = Get-EntryString -Entry $Item -Key 'downloadedAt'
        lastCheckedAt       = Get-EntryString -Entry $Item -Key 'lastCheckedAt'
        expectedHash        = Get-EntryString -Entry $Item -Key 'expectedHash'
        expectedAlgorithm   = Get-EntryString -Entry $Item -Key 'expectedAlgorithm'
        checksumHashFile    = Get-EntryString -Entry $Item -Key 'checksumHashFile'
        checksumHashFrom    = Get-EntryString -Entry $Item -Key 'checksumHashFrom'
        checksumFingerprint = Get-EntryString -Entry $Item -Key 'checksumFingerprint'
    }
    if ($null -ne $Item -and [string]::IsNullOrWhiteSpace($meta.manifestOrigin)) {
        $meta.manifestOrigin = Get-WinstOfficialManifestName
    }
    if ($NormalizeDigest) {
        $meta.expectedHash = $meta.expectedHash.ToLowerInvariant()
        $meta.expectedAlgorithm = $meta.expectedAlgorithm.ToUpperInvariant()
        $meta.checksumFingerprint = $meta.checksumFingerprint.ToLowerInvariant()
    }
    return $meta
}
