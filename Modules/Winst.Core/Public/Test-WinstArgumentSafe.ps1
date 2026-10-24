#Requires -Version 5.1

function Test-WinstArgumentSafe {
    <#
    .SYNOPSIS
        判断一个值能否安全地作为单个命令行参数传给外部程序（不含双引号与控制字符）。
    .DESCRIPTION
        路径 / 版本号 / 开关这些值最终会拼进 msiexec、7z、卸载器命令行：值里出现 `"` 就能提前闭合引号、
        追加任意参数（如安装目录写成 `C:\x" & calc & "`）。这些值本来就不允许含引号，
        在拼接前显式拒绝，而不是靠调用方各自记得转义。
    .OUTPUTS
        [bool]
    #>
    param([string]$Value)

    if ($null -eq $Value) { return $true }
    $text = [string]$Value
    if ($text -match '"') { return $false }
    if ($text -match '[\x00-\x1F]') { return $false }
    return $true
}
