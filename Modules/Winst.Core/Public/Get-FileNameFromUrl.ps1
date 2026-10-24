#Requires -Version 5.1

function Get-FileNameFromUrl {
    <#
    .SYNOPSIS
        从 URL 提取文件名（去查询串 / 片段，并还原百分号编码）。
    .DESCRIPTION
        SourceForge 等站点的标准下载地址形如 …/<文件名>/download：末段是动作名而不是文件名，
        此时取上一段（如 …/KeePass-2.61.1.zip/download → KeePass-2.61.1.zip）。
    #>
    param([string]$Url)

    if ($null -eq $Url -or -not $Url) { return '' }
    $text = ([string]$Url).Trim()
    $cut = $text.IndexOfAny([char[]]@('?', '#'))
    if ($cut -ge 0) { $text = $text.Substring(0, $cut) }
    $slash = $text.LastIndexOf('/')
    $name = $text
    if ($slash -ge 0) { $name = $text.Substring($slash + 1) }
    if ($name -ieq 'download' -and $slash -gt 0) {
        $parent = $text.Substring(0, $slash)
        $prevSlash = $parent.LastIndexOf('/')
        if ($prevSlash -ge 0) { $name = $parent.Substring($prevSlash + 1) } else { $name = $parent }
    }
    try { $name = [Uri]::UnescapeDataString($name) } catch { }
    return $name.Trim()
}
