#Requires -Version 5.1

function Test-WinstIsAdministrator {
    <#
    .SYNOPSIS
        当前进程是否具有管理员权限（Machine 级环境变量写入需要）。
    #>
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}
