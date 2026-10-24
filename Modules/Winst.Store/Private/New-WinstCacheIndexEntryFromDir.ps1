#Requires -Version 5.1

function New-WinstCacheIndexEntryFromDir {
    <#
    .SYNOPSIS
        按某个 id 目录内的文件构造一条索引记录（整份索引重建 / 单条记录读坏时使用）。
    .DESCRIPTION
        版本、校验码、新鲜度基线都无从得知：版本记空串（安装 / 下载时会自动核对并回写），
        校验码与记账留空（首次用到时再建立），downloadedAt 取目录内最新的文件写入时间。
        目录内没有文件时返回 $null（不建空条目）。
    #>
    param([Parameter(Mandatory = $true)][string]$Dir)

    $files = @(Get-ChildItem -LiteralPath $Dir -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return $null }

    $names = New-Object 'System.Collections.Generic.List[string]'
    $latest = $null
    foreach ($file in $files) {
        $names.Add([string]$file.Name)
        if ($null -eq $latest -or $file.LastWriteTime -gt $latest) { $latest = $file.LastWriteTime }
    }
    $stamp = ''
    if ($latest) { $stamp = $latest.ToString('s') }
    return [ordered]@{
        version        = ''
        files          = @($names.ToArray())
        hashes         = (New-WinstOrdinalDictionary)   # 重建时不知道校验码，首次用到时再算一次并写回
        manifestHashes = (New-WinstOrdinalDictionary)
        fileMeta       = (New-WinstOrdinalDictionary)      # 重建时也不知道记账，首次用到时再建立基线
        downloadedAt   = $stamp
    }
}
