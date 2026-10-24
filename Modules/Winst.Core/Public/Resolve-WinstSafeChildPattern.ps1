#Requires -Version 5.1

function Resolve-WinstSafeChildPattern {
    <#
    .SYNOPSIS
        把仅允许 `*` / `?` 通配符的包内相对模式安全地拼到根目录下。
    .DESCRIPTION
        用于 postInstallCopy.from 与 installerExe。逐段校验规则见 Split-WinstSafeChildSegments；
        额外拒绝控制字符与 `[` `]`，且边界复核走「通配符替换成 x」的等价普通路径
        （.NET Framework 的 GetFullPath 拒绝 `*` / `?`）。
    .OUTPUTS
        @{ Ok; Path; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Child,
        [string]$Label = '路径'
    )

    $checked = Split-WinstSafeChildSegments -Root $Root -Child $Child -Label $Label -AllowWildcard
    return @{ Ok = [bool]$checked.Ok; Path = [string]$checked.Path; Error = [string]$checked.Error }
}
