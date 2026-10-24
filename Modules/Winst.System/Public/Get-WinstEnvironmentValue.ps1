#Requires -Version 5.1

function Get-WinstEnvironmentValue {
    <#
    .SYNOPSIS
        读某个作用域下环境变量的当前值（原样返回；没有这个变量时返回 $null）。
    .DESCRIPTION
        Win32_Environment 给的是库里的原值（`%VAR%` 不展开），因此能与清单里的写法逐字比较，
        不会像 .NET 的 GetEnvironmentVariable 那样把 REG_EXPAND_SZ 展开后再拿来比。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('User', 'Machine')][string]$Scope
    )

    $instances = @(Get-WinstEnvironmentInstance -Name $Name -Scope $Scope)
    if ($instances.Count -eq 0) { return $null }
    return [string]$instances[0].VariableValue
}
