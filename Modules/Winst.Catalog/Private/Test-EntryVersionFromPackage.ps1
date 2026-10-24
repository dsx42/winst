#Requires -Version 5.1

function Test-EntryVersionFromPackage {
    <#
    .SYNOPSIS
        条目是否声明「版本号等主包下载后从文件信息取」。
    .DESCRIPTION
        版本号来源是 source.versionFrom 一根轴：direct 源可写 page（从官网页面实时取）或 package（等取包）；
        page 源可写 url（默认，从命中的下载地址识别）/ page（从页面内容识别）/ package；github 源可写
        tag（默认，发布 tag 当版本号）/ file（从下载文件名识别）/ package。声明 package 即「软件源里没有
        版本号，等主包取到后读文件信息」，来源解析要放行「没有版本号」，计划里记成 versionFromPackage。
        这一判断由来源解析与计划构建共用，避免各写一套。
    .OUTPUTS
        [bool]
    #>
    param($Entry)

    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    return ((Get-EntryString -Entry $source -Key 'versionFrom').Trim().ToLowerInvariant() -eq 'package')
}
