#Requires -Version 5.1

function Get-WinstEnvironmentInstance {
    <#
    .SYNOPSIS
        取 Win32_Environment 里指定作用域 + 名字的实例（没有则返回 @()）。
    .DESCRIPTION
        查询只按类枚举（不拼 WQL 过滤字符串：UserName 里的反斜杠进 WQL 要转义，容易写错），
        作用域在 PowerShell 侧判定——Machine = `SystemVariable` 为真；
        User = `SystemVariable` 为假**且** `UserName` 等于当前账号（provider 会把其它账号
        （如 NT AUTHORITY\SYSTEM）的用户变量一并列出来，只看名字会误伤）。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('User', 'Machine')][string]$Scope
    )

    $wantUser = ''
    if ($Scope -eq 'User') { $wantUser = Get-WinstEnvironmentUserName -Scope 'User' }

    # 短 TTL 快照：每条环境变量 / PATH 项的读写都会问一次「这个变量现在是什么值」，
    # 一次安装约 2N 次调用，而 Win32_Environment 全量枚举每次都是几百毫秒级。
    # 写入侧（Set / Remove-WinstEnvironmentVariableEx）立即失效，TTL 只兜底外部修改。
    $instances = @()
    try {
        $cacheValid = $false
        if ((Get-WinstState -Name WinstEnvironmentCache)) {
            $age = ((Get-Date) - [datetime](Get-WinstState -Name WinstEnvironmentCache)['At']).TotalSeconds
            if ($age -ge 0 -and $age -lt 15) { $cacheValid = $true }
        }
        if ($cacheValid) {
            $instances = @((Get-WinstState -Name WinstEnvironmentCache)['Items'])
        } else {
            $instances = @(Get-CimInstance -ClassName Win32_Environment -ErrorAction Stop)
            $null = Set-WinstState -Name WinstEnvironmentCache -Value (@{ At = (Get-Date); Items = $instances })
        }
    } catch {
        throw ('读取系统环境变量失败（Win32_Environment）：{0}' -f $_.Exception.Message)
    }

    $hit = New-Object 'System.Collections.Generic.List[object]'
    foreach ($instance in $instances) {
        if (-not ([string]$instance.Name -ieq $Name)) { continue }
        if ($Scope -eq 'Machine') {
            if (-not $instance.SystemVariable) { continue }
        } else {
            if ($instance.SystemVariable) { continue }
            if (-not $wantUser) { continue }
            if (-not ([string]$instance.UserName -ieq $wantUser)) { continue }
        }
        $hit.Add($instance)
    }
    return @($hit.ToArray())
}
