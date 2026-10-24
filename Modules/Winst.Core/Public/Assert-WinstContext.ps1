#Requires -Version 5.1

function Assert-WinstContext {
    <#
    .SYNOPSIS
        校验运行上下文：缺失时打印统一提示并返回假，调用方据此直接返回。
    .DESCRIPTION
        交互流程统一的上下文校验，提示文案只在这里定义。
    .OUTPUTS
        [bool]
    #>
    param([hashtable]$Context)

    if ($Context) { return $true }
    Write-Host '  内部错误：缺少运行上下文。' -ForegroundColor Red
    return $false
}
