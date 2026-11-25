#Requires -Version 5.1

function Clear-WinstReplacedPackageRecord {
    <#
    .SYNOPSIS
        发布新文件前撤销同名文件的旧登记，避免中途失败后从新文件读取到旧版本或摘要。
    #>
    param([string]$PkgDir, [string]$Id, $Entry, [string]$Name, [switch]$Main)

    if (-not $Entry -or (-not $Main -and @(Get-EntryArray -Entry $Entry -Key 'files') -notcontains $Name)) { return }

    Save-WinstCacheIndex -PkgDir $PkgDir -UpdateIds @($Id) -Update {
        param($index)
        if (-not $index.Contains($Id)) { return }
        $current = $index[$Id]
        if ($Main) {
            $current['version'] = ''
            $current['downloadedAt'] = ''
        }
        foreach ($key in @('hashes', 'manifestHashes', 'fileMeta')) {
            $map = Get-EntryValue -Entry $current -Key $key
            if ($map) { $null = $map.Remove($name) }
        }
    }
}
