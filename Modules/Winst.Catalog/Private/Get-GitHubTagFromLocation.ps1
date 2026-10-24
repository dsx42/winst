#Requires -Version 5.1

function Get-GitHubTagFromLocation {
    <#
    .SYNOPSIS
        从地址 / 页面内容里取出 /releases/tag/<tag> 的 tag 文本（百分号解码）。
    #>
    param([string]$Text)

    if (-not $Text) { return '' }
    $m = [regex]::Match($Text, '/releases/tag/(.+?)(?:["''?#<>]|$)')
    if (-not $m.Success) { return '' }

    $tag = $m.Groups[1].Value
    try { $tag = [Uri]::UnescapeDataString($tag) } catch { }
    return $tag.Trim()
}
