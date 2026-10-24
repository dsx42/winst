#Requires -Version 5.1

function Format-WinstBareVersionValue {
    <#
    .SYNOPSIS
        判断一段文本「整体是否就是一个版本号」，是则原样返回，否则返回空串。
    .DESCRIPTION
        供未声明 versionKind 的检测途径使用：`1.8.0_504-b01`、`25.0.4.1+1`、`v1.2.3` 这类单行版本号原样保留；
        多行内容、带说明文字的文件名（`MPC-BE.1.9.1.75_git.x64.7z`）、`unknown` 之类一律返回空。
    .OUTPUTS
        [string]
    #>
    param([string]$Text)

    $one = ([string]$Text).Trim()
    if (-not $one) { return '' }
    # 多行 / 过长 / 含空白的都不是「一个版本号」，而是文档或文件名
    if ($one -match '[\r\n\t]') { return '' }
    if ($one.Length -gt 64) { return '' }
    if ($one -match '\s') { return '' }
    if ($one -notmatch '^[vV]?[0-9][0-9A-Za-z._+\-~]*$') { return '' }
    return $one
}
