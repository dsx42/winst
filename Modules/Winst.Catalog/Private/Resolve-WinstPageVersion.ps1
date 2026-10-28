#Requires -Version 5.1

function Resolve-WinstPageVersion {
    <#
    .SYNOPSIS
        从页面数据字段（versionKey）或 versionFrom 指定的位置识别版本，最后回退条目里的 version。
    .OUTPUTS
        @{ Error; Version }
    #>
    param($Entry, $Source, [string]$Html, [string]$DownloadUrl, [string]$VersionFrom, [string]$PageUrl)

    $versionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    if ($versionKey) {
        $found = Get-VersionKeyValue -Text $Html -Key $versionKey
        if (-not $found.Ok) {
            return @{ Error = ('下载页 {0} 上没有找到版本字段「{1}」；可能是页面结构变更，需要更新软件源' -f $PageUrl, $versionKey); Version = '' }
        }
        return @{ Error = ''; Version = (Get-NormalizedVersionString -Value $found.Value) }
    }

    if ($VersionFrom -eq 'package') {
        # 版本号等主包下载后从文件信息取：页面 / 地址里不找版本，
        # 清单 version 仍可写（用于展示与配套文件 {version} 展开的兜底）
        return @{ Error = ''; Version = (Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')) }
    }

    $versionSourceText = $DownloadUrl
    $versionSourceWhere = '下载地址'
    if ($VersionFrom -eq 'page') { $versionSourceText = $Html; $versionSourceWhere = '页面内容' }

    $found = Get-VersionFromSourceText -Source $Source -Text $versionSourceText -Where $versionSourceWhere
    if ($found.Missing) {
        return @{ Error = ''; Version = (Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')) }
    }
    if (-not $found.Ok) {
        return @{ Error = ('无法从下载页 {0} 上识别出版本号（{1}）；可能是页面结构变更，需要更新软件源' -f $PageUrl, $found.Error); Version = '' }
    }
    return @{ Error = ''; Version = [string]$found.Version }
}
