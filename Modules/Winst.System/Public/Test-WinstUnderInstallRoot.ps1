#Requires -Version 5.1

function Test-WinstUnderInstallRoot {
    <#
    .SYNOPSIS
        判断路径是否位于 installRoot 之下（大小写不敏感，含 installRoot 本身，按目录边界比较）。
    .DESCRIPTION
        注册表扫描与目录登记共用本函数。两条来源给出的路径写法经常不同（`..` 相对段、`C:/` 正斜杠、
        `\\?\` 设备前缀、8.3 短名），纯字符串前缀比较会漏判或误判，因此统一交给
        `Test-WinstPathUnderRoot` 归一化后按目录边界比较。
    .OUTPUTS
        [bool]
    #>
    param([string]$Path, [string]$InstallRoot)

    if (-not $Path -or -not $InstallRoot) { return $false }
    return (Test-WinstPathUnderRoot -Path $Path -Root $InstallRoot -AllowEqual)
}
