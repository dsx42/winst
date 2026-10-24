#Requires -Version 5.1

function Get-WinstEnvironmentUserName {
    <#
    .SYNOPSIS
        某个作用域在 Win32_Environment 里的 UserName（User = 当前账号，Machine = `<system>`）。
    .DESCRIPTION
        用于按作用域创建 / 查找环境变量：Machine 用固定标识 `<system>`；User 用当前进程所属账号的
        `域\用户名` 写法（与 provider 自己返回的写法一致，如 `VIPSHOP\jason07.li`），
        取不到时退回 WindowsIdentity。
    #>
    param([Parameter(Mandatory = $true)][ValidateSet('User', 'Machine')][string]$Scope)

    if ($Scope -eq 'Machine') { return '<system>' }

    $userName = ''
    if ($env:USERDOMAIN -and $env:USERNAME) { $userName = ($env:USERDOMAIN + '\' + $env:USERNAME) }
    if (-not $userName) {
        try { $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $userName = '' }
    }
    return $userName
}
