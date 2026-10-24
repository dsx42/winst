#Requires -Version 5.1

function Get-HtmlAttributeValue {
    <#
    .SYNOPSIS
        从 HTML 标签的属性串中读取指定属性的值（支持双引号 / 单引号 / 无引号三种写法）。
    #>
    param(
        [string]$Attributes,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not $Attributes) { return '' }
    $pattern = '(?is)(?:^|\s)' + [regex]::Escape($Name) + '\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s>"'']+))'
    $m = [regex]::Match($Attributes, $pattern)
    if (-not $m.Success) { return '' }
    if ($m.Groups[1].Success) { return $m.Groups[1].Value }
    if ($m.Groups[2].Success) { return $m.Groups[2].Value }
    return $m.Groups[3].Value
}
