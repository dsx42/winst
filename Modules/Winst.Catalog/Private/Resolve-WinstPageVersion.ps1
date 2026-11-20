#Requires -Version 5.1

function Resolve-WinstPageVersion {
    <#
    .SYNOPSIS
        从页面字段或 versionFrom 指定的位置识别版本，未声明规则时版本为空。
    .OUTPUTS
        @{ Error; Version }
    #>
    param($Source, [string]$Html, [string]$DownloadUrl, [string]$VersionFrom, [string]$PageUrl, [hashtable]$Context)

    if (@('header', 'json') -contains $VersionFrom) {
        return @{ Error = ''; Version = (Resolve-WinstExternalVersion -Context $Context -Source $Source -VersionFrom $VersionFrom) }
    }

    $versionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    if ($versionKey) {
        $found = Get-VersionKeyValue -Text $Html -Key $versionKey
        if (-not $found.Ok) {
            return @{ Error = ('下载页 {0} 上没有找到版本字段「{1}」；可能是页面结构变更，需要更新软件源' -f $PageUrl, $versionKey); Version = '' }
        }
        $version = Get-NormalizedVersionString -Value $found.Value
        if (-not $version) {
            return @{ Error = ('下载页 {0} 的版本字段「{1}」为空，无法确定版本' -f $PageUrl, $versionKey); Version = '' }
        }
        return @{ Error = ''; Version = $version }
    }

    if ($VersionFrom -eq 'package') {
        # 主包下载后从包内读取版本。
        return @{ Error = ''; Version = '' }
    }

    $versionSourceText = $DownloadUrl
    $versionSourceWhere = '下载地址'
    if ($VersionFrom -eq 'page') { $versionSourceText = $Html; $versionSourceWhere = '页面内容' }

    $found = Get-VersionFromSourceText -Source $Source -Text $versionSourceText -Where $versionSourceWhere
    if ($found.Missing) {
        return @{ Error = ''; Version = '' }
    }
    if (-not $found.Ok) {
        return @{ Error = ('无法从下载页 {0} 上识别出版本号（{1}）；可能是页面结构变更，需要更新软件源' -f $PageUrl, $found.Error); Version = '' }
    }
    return @{ Error = ''; Version = [string]$found.Version }
}
