#Requires -Version 5.1

function ConvertTo-ShortcutName {
    <#
    .SYNOPSIS
        按固定命名规则生成快捷方式文件名（<name>.lnk，非法字符替换为 _）。
    #>
    param([string]$Name)

    $text = ''
    if ($null -ne $Name) { $text = ([string]$Name).Trim() }
    if (-not $text) { return '' }
    foreach ($ch in @(([char[]]@('\', '/', ':', '*', '?', '"', '<', '>', '|')))) {
        $text = $text.Replace($ch, '_')
    }
    return ($text + '.lnk')
}
