#Requires -Version 5.1

function Confirm-WinstSingleInstance {
    <#
    .SYNOPSIS
        单进程校验：同一份数据目录只允许一个 winst 在跑，已有实例时提示并拒绝启动。
    .DESCRIPTION
        为什么要拦：两次 winst 同时写同一份 state.json / winst.json / sources.json 时，
        后完成者会覆盖前者（写入是「临时文件 + 替换」的整份覆盖），并发装两个软件的结果是其中一条记录丢失。
        锁用独占句柄实现（见 Enter-WinstInstanceLock），进程被强杀不会留下永久占用。

        自动放行的两种情况：
        - `-v` / `--version` / `-h` / `--help` / `help`：只读、不碰数据文件，
          而且**别的 winst 进程会调用它们做版本检测**（清单里 winst 条目的 detect 就是 `winst.cmd -v`），
          拦下来会让自更新 / 已装软件列表卡死。
        - `WINST_NO_LOCK=1`：手动跳过（排障用，例如锁文件权限异常时仍要能查状态）。

        未放行且抢不到锁时返回 Allowed = $false，调用方应打印提示并直接退出。
    .OUTPUTS
        @{ Allowed; Skipped; OwnerPid; OwnerPath; OwnerStartedAt; LockPath }
    #>
    param([string[]]$Arguments = @())

    $result = @{
        Allowed        = $false
        Skipped        = $false
        OwnerPid       = 0
        OwnerPath      = ''
        OwnerStartedAt = ''
        LockPath       = ''
        Busy           = $false
        Error          = ''
    }

    if ($env:WINST_NO_LOCK -eq '1') { $result.Allowed = $true; $result.Skipped = $true; return $result }
    if (Test-WinstReadOnlyInvocation -Arguments $Arguments) { $result.Allowed = $true; $result.Skipped = $true; return $result }

    # 没取得锁就不能进入可能写入数据的业务逻辑。
    $lock = $null
    try {
        $lock = Enter-WinstInstanceLock
    } catch {
        $result.Error = $_.Exception.Message
        return $result
    }

    $result.LockPath = [string](Get-EntryString -Entry $lock -Key 'Path')
    if ($lock['Ok']) {
        $result.Allowed = $true
        return $result
    }

    $result.OwnerPid = [int]$lock['OwnerPid']
    $result.Busy = Get-EntryBool -Entry $lock -Key 'Busy'
    $result.Error = Get-EntryString -Entry $lock -Key 'Error'
    $result.OwnerPath = [string]$lock['OwnerPath']
    try {
        $owner = Read-WinstInstanceLockInfo -Path $result.LockPath
        $result.OwnerStartedAt = [string](Get-EntryString -Entry $owner -Key 'StartedAt')
    } catch {
        $result.OwnerStartedAt = ''
    }
    return $result
}
