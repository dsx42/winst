#Requires -Version 5.1

function Convert-WinstBoolText {
    <#
    .SYNOPSIS
        把布尔配置的常见写法（开 / 关、true / false、1 / 0 等）解析成布尔值；无法识别返回 $null。
    .DESCRIPTION
        config.json 允许手工编辑，设置页也接受「开 / 关」这类中文写法；读取与写入两处共用本函数，
        保证「关」不会被当成非空字符串而误判为开启（`[bool]'关'` 会得到 $true）。
    #>
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [bool]) { return [bool]$Value }
    $text = ([string]$Value).Trim().ToLowerInvariant()
    if (@('开', 'on', 'true', 'yes', 'y', '1') -contains $text) { return $true }
    if (@('关', 'off', 'false', 'no', 'n', '0') -contains $text) { return $false }
    return $null
}
