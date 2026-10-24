#Requires -Version 5.1

function ConvertTo-WinstDirPath {
    <#
    .SYNOPSIS
        归一化系统安装记录里的路径文本：去首尾空白 / 引号、展开 %VAR%、去掉末尾反斜杠（盘根 C:\ 保留）。
    #>
    param([string]$Text)

    if (-not $Text) { return '' }
    $value = ([string]$Text).Trim().Trim('"').Trim()
    if (-not $value) { return '' }
    if ($value -match '%[^%]+%') {
        try { $value = [Environment]::ExpandEnvironmentVariables($value) } catch { }
    }
    if ($value.Length -gt 3) { $value = $value.TrimEnd('\') }
    return $value
}
