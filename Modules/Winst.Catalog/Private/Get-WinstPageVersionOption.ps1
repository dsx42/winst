#Requires -Version 5.1

function Get-WinstPageVersionOption {
    <#
    .SYNOPSIS
        校验 page 源的版本来源（source.versionFrom）。
    .OUTPUTS
        @{ Error; VersionFrom }
    #>
    param($Source)

    # 版本号来源：url（默认，从命中的下载地址识别）/ page（从页面内容识别）
    # / package。先校验取值，免得拼错时静默按 url 处理。
    $versionFrom = (Get-EntryString -Entry $Source -Key 'versionFrom').Trim().ToLowerInvariant()
    if (-not $versionFrom) { $versionFrom = 'url' }
    if (@('url', 'page', 'package', 'header', 'json') -notcontains $versionFrom) {
        return @{ Error = ('不认识的版本来源「{0}」（source.versionFrom）；下载页来源可用 url / page / package / header / json' -f $versionFrom); VersionFrom = $versionFrom }
    }
    if ($versionFrom -eq 'package' -and ((Get-EntryString -Entry $Source -Key 'versionKey').Trim() -or (Get-EntryString -Entry $Source -Key 'versionKind').Trim() -or @(Get-EntryArray -Entry $Source -Key 'versionBetween').Count -gt 0)) {
        return @{ Error = '声明了 source.versionFrom: "package"（版本号等主包下载后从文件信息取）时不要再写 versionKey / versionKind / versionBetween——那些是从页面 / 地址里识别版本的写法'; VersionFrom = $versionFrom }
    }
    return @{ Error = ''; VersionFrom = $versionFrom }
}
