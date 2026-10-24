#Requires -Version 5.1

function Get-WinstPageVersionOption {
    <#
    .SYNOPSIS
        校验 page 源的版本来源（source.versionFrom）与包内版本派生规格（source.packageVersion）。
    .OUTPUTS
        @{ Error; VersionFrom }
    #>
    param($Source)

    # 版本号来源：url（默认，从命中的下载地址识别）/ page（从页面内容识别）
    # / package。先校验取值，免得拼错时静默按 url 处理。
    $versionFrom = (Get-EntryString -Entry $Source -Key 'versionFrom').Trim().ToLowerInvariant()
    if (-not $versionFrom) { $versionFrom = 'url' }
    if (@('url', 'page', 'package') -notcontains $versionFrom) {
        return @{ Error = ('不认识的版本来源「{0}」（source.versionFrom）；下载页来源可用 url（默认，从下载地址识别）/ page（从页面内容识别）/ package（版本号等主包下载后从文件信息取）' -f $versionFrom); VersionFrom = $versionFrom }
    }
    if ($versionFrom -eq 'package' -and ((Get-EntryString -Entry $Source -Key 'versionKey').Trim() -or (Get-EntryString -Entry $Source -Key 'versionKind').Trim() -or @(Get-EntryArray -Entry $Source -Key 'versionBetween').Count -gt 0)) {
        return @{ Error = '声明了 source.versionFrom: "package"（版本号等主包下载后从文件信息取）时不要再写 versionKey / versionKind / versionBetween——那些是从页面 / 地址里识别版本的写法'; VersionFrom = $versionFrom }
    }
    # source.packageVersion：校验写法并确认它只配合 versionFrom: "package" 使用
    $packageVersionSpec = Get-WinstPackageVersionSpec -Source $Source
    if (-not $packageVersionSpec.Ok) { return @{ Error = [string]$packageVersionSpec.Error; VersionFrom = $versionFrom } }
    if ($packageVersionSpec.Spec -and $versionFrom -ne 'package') {
        return @{ Error = 'source.packageVersion（包内版本派生规格）只配合 source.versionFrom: "package" 使用'; VersionFrom = $versionFrom }
    }

    return @{ Error = ''; VersionFrom = $versionFrom }
}
