#Requires -Version 5.1

function ConvertTo-HtmlText {
    <#
    .SYNOPSIS
        把 HTML 片段转为纯文本（去脚本 / 样式 / 标签，反转义实体，压缩空白）。
    #>
    param([string]$Html)

    if ($null -eq $Html -or -not $Html) { return '' }
    $text = $Html -replace '(?is)<(script|style)\b.*?</\1>', ' '
    $text = $text -replace '(?s)<[^>]*>', ' '
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}
