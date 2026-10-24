#Requires -Version 5.1

function Expand-ReleaseTagPlaceholder {
    <#
    .SYNOPSIS
        把文本中的 {tag} 占位符替换为 GitHub 发布 tag（按 URL 路径段转义）。
    .DESCRIPTION
        仅用于 github 源的 files[].url：让清单能直接写出
        https://github.com/<owner>/<repo>/releases/download/{tag}/<文件名> 形式的地址，
        从而不必再抓取资产列表，一次请求即可得到真实下载地址。
    #>
    param([string]$Text, [string]$Tag)

    if ($null -eq $Text) { return '' }
    $text = [string]$Text
    if (-not [regex]::IsMatch($text, '\{tag\}')) { return $text }

    $replacement = ''
    if ($Tag) { $replacement = [Uri]::EscapeDataString([string]$Tag) }
    $replacement = $replacement.Replace('$', '$$')
    return [regex]::Replace($text, '\{tag\}', $replacement)
}
