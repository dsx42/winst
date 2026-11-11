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
    foreach ($ch in [IO.Path]::GetInvalidFileNameChars()) { $text = $text.Replace($ch, '_') }
    $text = $text.TrimEnd(' ', '.')
    if (-not $text) { $text = '_' }
    if (Test-WinstReservedDeviceName -Name $text) { $text = '_' + $text }
    $fileName = $text + '.lnk'
    if (-not (Test-WinstSafePathSegment -Name $fileName -MaxLength 255)) {
        throw ('快捷方式名称无效或过长：{0}' -f $Name)
    }
    return $fileName
}
