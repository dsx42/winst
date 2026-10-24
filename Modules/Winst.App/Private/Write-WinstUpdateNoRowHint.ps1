#Requires -Version 5.1

function Write-WinstUpdateNoRowHint {
    <#
    .SYNOPSIS
        软件源里没有该软件时的提示（检查 / 更新两种口径）。
    #>
    param([string]$DisplayName, [switch]$Check, [switch]$Quiet)

    if ($Quiet) { return }
    Write-Host ''
    if ($Check) {
        Write-Host ('  {0}: 软件源里没有这个软件，无法检查更新（可在「高级功能 → 管理软件源」里刷新软件源）。' -f $DisplayName) -ForegroundColor DarkYellow
    } else {
        Write-Host ('  {0}: 软件源里没有这个软件（没有可安装的定义），已跳过更新；可到「高级功能 → 管理软件源」刷新软件源后重试。' -f $DisplayName) -ForegroundColor DarkYellow
    }
}
