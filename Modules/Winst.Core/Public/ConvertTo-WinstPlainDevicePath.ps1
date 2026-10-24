#Requires -Version 5.1

function ConvertTo-WinstPlainDevicePath {
    <#
    .SYNOPSIS
        去掉 Windows 设备路径前缀（`\\?\` / `\\.\` / `\\?\UNC\`），得到可供 GetFullPath 与路径比较使用的普通路径。
    .DESCRIPTION
        这些前缀会**真实到达文件系统**（`\\?\C:\Windows` 就是 `C:\Windows`），但字符串层面的
        受保护目录正则会把它当成以两个反斜杠开头的 UNC 路径而漏判，等于给「递归删除系统目录」留了后门。
        统一在路径校验前剥离前缀；`\\?\UNC\server\share` 还原成 `\\server\share`。
    .OUTPUTS
        [string]
    #>
    param([string]$Path)

    $text = [string]$Path
    if (-not $text) { return '' }
    if ($text.StartsWith('\\?\UNC\', [StringComparison]::OrdinalIgnoreCase)) {
        return ('\\' + $text.Substring(8))
    }
    # 只剥「后面确实跟着盘符」的设备前缀；`\\?\Volume{...}` / `\\?\GLOBALROOT\...` 保持原样，
    # 否则会被当成相对路径拼到当前目录下（既判错受保护目录，也可能指向完全不同的位置）。
    $stripLength = 0
    if ($text.StartsWith('\\?\', [StringComparison]::Ordinal)) { $stripLength = 4 }
    elseif ($text.StartsWith('\\.\', [StringComparison]::Ordinal)) { $stripLength = 4 }
    if ($stripLength -gt 0) {
        $rest = $text.Substring($stripLength)
        if ($rest -match '^[A-Za-z]:([\\/]|$)') { return $rest }
    }
    return $text
}
