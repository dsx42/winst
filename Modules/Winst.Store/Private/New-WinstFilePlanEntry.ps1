#Requires -Version 5.1

function New-WinstFilePlanEntry {
    <#
    .SYNOPSIS
        生成单个文件的计划骨架（字段顺序与调用方写回索引时一致）。
    .OUTPUTS
        [ordered]@{ ... }
    #>
    param($File, [string]$Url, [string]$Name)

    return [ordered]@{
        Url                   = $Url
        Name                  = $Name
        Target                = ''
        Decl                  = $File
        FileVersion           = [string](Get-EntryString -Entry $File -Key 'version')
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
