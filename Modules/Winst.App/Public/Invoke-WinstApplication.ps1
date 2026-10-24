#Requires -Version 5.1
<#
    Invoke-WinstApplication.ps1  (Winst.App / Public)

    winst.ps1 使用的唯一入口。

    职责
    ----
    1. 记录脚本位置（WinstScriptDir / WinstScriptPath），
       供本地清单发现与离线自安装定位正在运行的脚本。
    2. 单进程校验：同一份数据目录只允许一个 winst 在跑。
    3. 交给 Invoke-WinstEntry 做 CLI 解析、命令分发或进入菜单。
    4. 把返回值统一成单一 ExitCode 字段，winst.ps1 只需读一个属性；
       退出前释放单进程锁。

    为什么需要这层包装，而不是让 winst.ps1 直接调 Invoke-WinstEntry
    --------------------------------------------------------------
    Invoke-WinstEntry 拿不到调用方的 $PSCommandPath：在模块内部这些自动变量
    描述的是模块文件而不是 winst.ps1。因此由调用方传入真实路径，
    本包装在任何逻辑之前先把它们存好。

    退出码
    ------
        0  成功 / 用户取消 / 菜单正常返回
        1  参数错误、找不到目标、内部错误、已有另一个 winst 在运行
        2  网络失败
        3  安装 / 卸载 / 校验失败
        4  `update --check` 检测到可更新项
#>

function Invoke-WinstApplication {
    <#
    .SYNOPSIS
        运行 winst：单进程校验 → 解析命令行 → 分发命令或进入菜单。

    .PARAMETER Root
        包含 winst.ps1 与 Modules 目录的路径。

    .PARAMETER Arguments
        原始命令行 token，与 $args 收到的一致。

    .PARAMETER ScriptPath
        正在运行的 winst.ps1 完整路径，默认 <Root>\winst.ps1。

    .OUTPUTS
        [pscustomobject]，含 Ok、ExitCode、Message
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [string[]]$Arguments = @(),

        [string]$ScriptPath = ''
    )

    $result = [pscustomobject]@{
        PSTypeName = 'Winst.ApplicationResult'
        Ok         = $false
        ExitCode   = 0
        Message    = ''
    }

    if (-not $ScriptPath) {
        $ScriptPath = Join-Path $Root 'winst.ps1'
    }

    # 必须在任何其它模块运行之前完成：本地清单发现要读 WinstScriptDir，
    # 离线自安装要读 WinstScriptPath，单进程锁要在锁文件内容里记下运行路径。
    $null = Set-WinstScriptLocation -ScriptPath $ScriptPath -Directory $Root

    # —— 单进程校验：抢不到锁就提示并退出，不进任何业务逻辑 ——
    $instance = Confirm-WinstSingleInstance -Arguments $Arguments
    if (-not $instance.Allowed) {
        Write-WinstInstanceBusyMessage -Instance $instance
        $result.ExitCode = 1
        $result.Message = '已经有一个 winst 正在运行'
        return $result
    }

    try {
        $exitCode = Invoke-WinstEntry -Arguments $Arguments

        if ($null -eq $exitCode) {
            $result.ExitCode = 0
        } else {
            $result.ExitCode = [int]$exitCode
        }

        $result.Ok = ($result.ExitCode -eq 0 -or $result.ExitCode -eq 4)
        return $result
    } catch {
        $result.Ok = $false
        $result.ExitCode = 1
        $result.Message = $_.Exception.Message
        throw
    } finally {
        # 只读调用没有抢锁（Skipped），这里也就不用放；Exit-WinstInstanceLock 自己会判空
        Exit-WinstInstanceLock
    }
}
