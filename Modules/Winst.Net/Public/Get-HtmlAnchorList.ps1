#Requires -Version 5.1

function Get-HtmlAnchorList {
    <#
    .SYNOPSIS
        解析页面中的全部 <a> 锚点，返回 @{ Href; Class; Id; Text } 列表。
    .DESCRIPTION
        供 page 源按 link（class / id / text / href）与文件名规则挑选下载链接使用。
    #>
    param([string]$Html)

    $result = New-Object 'System.Collections.Generic.List[object]'
    if (-not $Html) { return @() }

    foreach ($m in [regex]::Matches($Html, '(?is)<a\b([^>]*)>(.*?)</a\s*>')) {
        $attrs = $m.Groups[1].Value
        $href = Get-HtmlAttributeValue -Attributes $attrs -Name 'href'
        if (-not $href -or -not $href.Trim()) { continue }
        $result.Add([ordered]@{
            Href  = ([System.Net.WebUtility]::HtmlDecode($href)).Trim()
            Class = (Get-HtmlAttributeValue -Attributes $attrs -Name 'class').Trim()
            Id    = (Get-HtmlAttributeValue -Attributes $attrs -Name 'id').Trim()
            Text  = ConvertTo-HtmlText -Html $m.Groups[2].Value
        })
    }
    return $result.ToArray()
}
