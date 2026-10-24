#Requires -Version 5.1

function Remove-WinstEnvironmentVariableEx {
    <#
    .SYNOPSIS
        删除环境变量（User / Machine 作用域）并在当前会话生效。
    .DESCRIPTION
        Machine 级需要管理员权限，无权限时明确报错。
        与写入对称地走 WMI `Win32_Environment`；
        当前会话用 .NET API 的 `Process` 作用域清除（WMI 管不到进程环境，作用域用
        `[System.EnvironmentVariableTarget]` 枚举显式指定）。
    .OUTPUTS
        [bool] 是否删除了已存在的变量
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('User', 'Machine')][string]$Scope
    )

    if ($Scope -eq 'Machine' -and -not (Test-WinstIsAdministrator)) {
        throw ('需要管理员权限才能删除系统级环境变量（{0}）。请以管理员身份运行 winst 后重试。' -f $Name)
    }

    $instances = @(Get-WinstEnvironmentInstance -Name $Name -Scope $Scope)
    foreach ($instance in $instances) {
        try {
            Remove-CimInstance -InputObject $instance -ErrorAction Stop
        } catch {
            throw ('删除环境变量失败（{0}）：{1}' -f $Name, $_.Exception.Message)
        }
    }

    try { [Environment]::SetEnvironmentVariable($Name, [NullString]::Value, [System.EnvironmentVariableTarget]::Process) } catch { }
    $null = Set-WinstState -Name WinstEnvironmentCache -Value ($null)
    Send-WinstSettingChange
    return ($instances.Count -gt 0)
}
