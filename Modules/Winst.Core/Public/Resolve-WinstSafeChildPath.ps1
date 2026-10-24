#Requires -Version 5.1

function Resolve-WinstSafeChildPath {
    <#
    .SYNOPSIS
        把一个「包内相对路径」（stripTopDir / extractFiles / postInstallCopy 的 to）安全地拼到根目录下。
    .DESCRIPTION
        逐段校验规则见 Split-WinstSafeChildSegments（本函数只是它的「不允许通配符」入口）。
        `.` 段（`./foo` 这类写法）直接跳过，等价于 `foo`。
    .OUTPUTS
        @{ Ok; Path; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Child,
        [string]$Label = '路径'
    )

    $checked = Split-WinstSafeChildSegments -Root $Root -Child $Child -Label $Label
    return @{ Ok = [bool]$checked.Ok; Path = [string]$checked.Path; Error = [string]$checked.Error }
}
