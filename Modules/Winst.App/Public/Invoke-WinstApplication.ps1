#Requires -Version 5.1

function Invoke-WinstApplication {
    <#
    .SYNOPSIS
        登记入口位置，取得实例锁后分发命令或进入菜单。

    .PARAMETER Root
        包含 winst.ps1 与 Modules 目录的路径。

    .PARAMETER Parsed
        入口已解析的参数，可供提权、实例锁与命令分发共用。

    .OUTPUTS
        [int] 退出码
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        $Parsed
    )

    Set-WinstScriptLocation -ScriptPath (Join-WinstPath $Root 'winst.ps1') -Directory $Root

    # —— 单进程校验：抢不到锁就提示并退出，不进任何业务逻辑 ——
    $instance = Confirm-WinstSingleInstance -Parsed $parsed
    if (-not $instance.Allowed) {
        Write-WinstInstanceBusyMessage -Instance $instance
        return 1
    }

    try {
        return [int](Invoke-WinstEntry -Parsed $Parsed)
    } finally {
        Exit-WinstInstanceLock
    }
}
