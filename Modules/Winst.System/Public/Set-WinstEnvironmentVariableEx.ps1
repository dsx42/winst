#Requires -Version 5.1

function Set-WinstEnvironmentVariableEx {
    <#
    .SYNOPSIS
        写入环境变量（User / Machine 作用域），并在当前会话生效。
    .DESCRIPTION
        Machine 级需要管理员权限，无权限时明确报错。
        **写入 / 查找走 WMI `Win32_Environment`**（`New-CimInstance` 新建、`Set-CimInstance` 覆盖）：
        provider 会按值里有没有 `%` 落 `REG_EXPAND_SZ` / `REG_SZ`，`REG_EXPAND_SZ` 的 `%VAR%`
        由 Windows 在读取时展开——这正是「引用其它环境变量」要的语义；**.NET 的 Environment API
        会把值一律写成 `REG_SZ`（`%VAR%` 不展开），因此不用它写库**。
        `%VAR%` 原样写入（winst 不做替换）；当前会话用 .NET API 的 `Process` 作用域生效
        （WMI 管不到进程环境，作用域用 `[System.EnvironmentVariableTarget]` 枚举显式指定）。
        值为空串时按「删除该项」处理。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory = $true)][ValidateSet('User', 'Machine')][string]$Scope
    )

    if ($Scope -eq 'Machine' -and -not (Test-WinstIsAdministrator)) {
        throw ('需要管理员权限才能写入系统级环境变量（{0}）。请以管理员身份运行 winst 后重试。' -f $Name)
    }

    if (-not $Value) {
        # WMI 不接受空值：按「删除该项」处理（清掉库里的旧值，不留下脏数据）
        $null = Remove-WinstEnvironmentVariableEx -Name $Name -Scope $Scope
        return
    }

    try {
        $instances = @(Get-WinstEnvironmentInstance -Name $Name -Scope $Scope)
        if ($instances.Count -gt 0) {
            $instances | Set-CimInstance -Property @{ VariableValue = $Value } -ErrorAction Stop
        } else {
            $userName = Get-WinstEnvironmentUserName -Scope $Scope
            if (-not $userName) { throw ('取不到当前账号名，无法写入用户级环境变量（{0}）。' -f $Name) }
            $null = New-CimInstance -ClassName Win32_Environment -Property @{ Name = $Name; VariableValue = $Value; UserName = $userName } -ErrorAction Stop
        }
    } catch {
        throw ('写入环境变量失败（{0}）：{1}' -f $Name, $_.Exception.Message)
    }

    # 当前会话生效（%VAR% 按当前进程环境展开）
    $sessionValue = [Environment]::ExpandEnvironmentVariables($Value)
    try { [Environment]::SetEnvironmentVariable($Name, $sessionValue, [System.EnvironmentVariableTarget]::Process) } catch { }
    # 库里的值已变：清掉 Win32_Environment 快照，后续读取必须看到新值（TTL 只是外部修改的兜底）
    $null = Set-WinstState -Name WinstEnvironmentCache -Value ($null)
    Send-WinstSettingChange
}
