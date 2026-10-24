#Requires -Version 5.1

function Write-WinstUnknownSubcommand {
    <#
    .SYNOPSIS
        子命令无法识别时的统一提示（manifest / config / bundle 共用）。
    .DESCRIPTION
        四处原本各写一遍「空行 + 未知的子命令 + 用法」，文案容易不一致；这里只统一起头，
        具体用法仍交给各自的 help 函数或 Usage 文本。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Sub,
        [string]$Usage = '',
        [string]$HelpFunction = ''
    )

    Write-Host ''
    Write-Host ('  未知的子命令: {0}' -f $Sub) -ForegroundColor Yellow
    if ($HelpFunction) { & $HelpFunction }
    elseif ($Usage) { Write-Host ('  用法: {0}' -f $Usage) -ForegroundColor Gray }
}
