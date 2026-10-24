#Requires -Version 5.1

function Get-WinstSourceEntries {
    <#
    .SYNOPSIS
        读取某个软件源的软件定义条目：本地清单直接读文件，远程来源读清单缓存。
    .OUTPUTS
        @{ Entries; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $result = @{ Entries = @(); Error = '' }

    if (Get-EntryBool -Entry $Source -Key 'isLocal') {
        $bundle = Read-LocalManifestBundle -Context $Context -Source $Source
        $result.Entries = @($bundle.Entries)
        $result.Error = [string]$bundle.Error
        return $result
    }

    $name = [string]$Source['name']
    $cachePath = Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $name
    if (-not $cachePath -or -not (Test-Path -LiteralPath $cachePath -PathType Leaf)) {
        $result.Error = '还没有这个软件源的清单缓存，请先刷新软件源'
        return $result
    }

    try {
        $raw = Get-Content -LiteralPath $cachePath -Raw -Encoding UTF8
        if (-not $raw -or -not $raw.Trim()) {
            $result.Error = '软件源的清单缓存是空文件，请重新刷新'
            return $result
        }
        $obj = $raw | ConvertFrom-Json
        $result.Entries = @(Get-ManifestEntries -Manifest $obj)
    } catch {
        $result.Error = ('读取软件源的清单缓存失败: {0}' -f $_.Exception.Message)
    }
    return $result
}
