#Requires -Version 5.1

function Get-WinstUpdateModeText {
    <#
    .SYNOPSIS
        更新方式的显示文本（keep = 只更新文件；full = 完整更新、覆盖已存在项）。
    .DESCRIPTION
        文本会被放进「u) 更新（…）」的括号里，因此不内嵌括号，避免出现「括号里套括号」。

        keep 档在更新时**不动环境变量 / PATH**，但会校验并修正已存在的快捷方式
        （安装位置换过以后旧 .lnk 指向空目录，双击打不开）。文案照这个口径写，
        不写「补齐缺失项」——那是首次安装才有的行为，也不写快捷方式「保持原样」——那是错的。
    #>
    param([string]$Mode)

    if ($Mode -eq 'full') { return '完整更新，覆盖已有的环境变量 / 快捷方式' }
    return '只更新文件，环境变量保持原样，快捷方式只修正不新建'
}
