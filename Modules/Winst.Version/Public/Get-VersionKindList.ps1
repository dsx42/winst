#Requires -Version 5.1

function Get-VersionKindList {
    <#
    .SYNOPSIS
        返回支持的版本识别器关键字列表（供报错提示）。
    #>
    return @('semver', 'date', 'digits')
}
