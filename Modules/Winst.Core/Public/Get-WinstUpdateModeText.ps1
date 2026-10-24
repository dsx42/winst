#Requires -Version 5.1

function Get-WinstUpdateModeText {
    <#
    .SYNOPSIS
        更新方式的显示文本（keep = 只更新文件；full = 完整更新、覆盖已存在项）。
    .DESCRIPTION
        文本会被放进「u) 更新（…）」的括号里，因此不内嵌括号，避免出现「括号里套括号」。
        keep 档在更新时**完全不动**环境变量 / PATH / 快捷方式，文案照这个口径写，
        不写「补齐缺失项」——那是首次安装才有的行为。
    #>
    param([string]$Mode)

    if ($Mode -eq 'full') { return '完整更新，覆盖已有的环境变量 / 快捷方式' }
    return '只更新文件，环境变量 / 快捷方式保持原样'
}
