#Requires -Version 5.1

function New-WinstCacheIndexEntryFromDir {
    <#
    .SYNOPSIS
        按某个 id 目录内的文件构造一条索引记录（整份索引重建 / 单条记录读坏时使用）。
    .DESCRIPTION
        版本、摘要和下载时间仅能由登记取得，重建时留空。
        目录内没有文件时返回 $null（不建空条目）。
    #>
    param([Parameter(Mandatory = $true)][string]$Dir)

    $files = @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return $null }

    return [ordered]@{
        version        = ''
        files          = @($files.Name)
        hashes         = (New-WinstOrdinalDictionary)   # 重建时不知道校验码，首次用到时再算一次并写回
        manifestHashes = (New-WinstOrdinalDictionary)
        fileMeta       = (New-WinstOrdinalDictionary)      # 重建时也不知道记账，首次用到时再建立基线
        downloadedAt   = ''
    }
}
