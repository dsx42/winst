#Requires -Version 5.1

function New-WinstFilePlanEntry {
    <#
    .SYNOPSIS
        生成单个文件的计划骨架（字段顺序与调用方写回索引时一致）。
    .OUTPUTS
        [ordered]@{ ... }
    #>
    param($File, [string]$Url, [string]$Name, [int]$FileIndex = 0)

    # 只有「这个文件自己的版本」才参与版本优先判定与索引记账：主包恒有；附加文件只有声明
    # versionListUrl 并独立取版时才有，其余跟随主包版本的记录只用于地址模板展开。
    # 旧解析锁里没有 versionOwned：主包按「有自身版本」处理，附加文件按「跟随主包版本」处理。
    $ownedValue = Get-EntryValue -Entry $File -Key 'versionOwned' -Default $null
    $versionOwned = ($FileIndex -eq 0)
    if ($null -ne $ownedValue) { $versionOwned = [bool]$ownedValue }
    $fileVersion = ''
    if ($versionOwned) { $fileVersion = [string](Get-EntryString -Entry $File -Key 'version') }

    return [ordered]@{
        Url                   = $Url
        Name                  = $Name
        Target                = ''
        Decl                  = $File
        CachedMeta            = $null
        FileVersion           = $fileVersion
        VersionOwned          = $versionOwned
        Compare               = [string](Get-EntryString -Entry $File -Key 'compare')
        NeedDownload          = $true
        Reason                = ''
        Notice                = ''
        Hint                  = ''
        ValidationError       = ''
        ValidationNetwork     = $false
        Refresh               = 'auto'
        RefreshMaxAgeHours    = 168
        MetaUrl               = ''
        ExpectedHash          = ''
        ExpectedAlgorithm     = ''
        RecordedHash          = ''
        IndexHash             = ''
        ManifestHash          = ''
        ActualHash            = ''
        ChecksumHashFile      = ''
        ChecksumHashFrom      = ''
        ChecksumFingerprint   = ''
        ChecksumMetadataAction = 'preserve'
        ValidatorETag         = ''
        ValidatorLastModified = ''
        ValidatorSize         = $null
        CheckedAt             = ''
    }
}
