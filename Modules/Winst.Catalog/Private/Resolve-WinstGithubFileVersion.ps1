#Requires -Version 5.1

function Resolve-WinstGithubFileVersion {
    <#
    .SYNOPSIS
        ④ versionFrom: file —— 从主包文件名里识别真实版本（识别不出即报错，不静默退回 tag 版本）。
    .OUTPUTS
        @{ Error }
    #>
    param($Files, [string]$ChosenTag, [string]$Version, [string]$VersionKind, $VersionBetween, $Result)

    $versionText = ''
    if (@($Files).Count -gt 0) {
        $versionText = [string]$Files[0]['name']
        if (-not $versionText) { $versionText = [string]$Files[0]['url'] }
    }
    $identified = Get-WinstVersionFromText -Text $versionText -Kind $VersionKind -Between $VersionBetween
    if (-not $identified) {
        return @{ Error = ('无法从下载文件名「{0}」里识别出版本号（versionKind / versionBetween 都没有命中）；可能是上游改了打包命名，需要更新软件源' -f $versionText) }
    }
    $identified = Get-NormalizedVersionString -Value $identified
    if ($identified -ne $Version) {
        $Result.Notes += ('版本号取自下载文件名: {0}（本次发布 tag 是 {1}）' -f $identified, $ChosenTag)
    }
    $Result.Version = $identified
    return @{ Error = '' }
}
