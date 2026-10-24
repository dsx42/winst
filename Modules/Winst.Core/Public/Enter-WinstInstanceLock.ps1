#Requires -Version 5.1

function Enter-WinstInstanceLock {
    <#
    .SYNOPSIS
        取得单进程锁；已被别的 winst 持有时返回 Ok = $false 与占用者信息。
    .DESCRIPTION
        用「独占句柄」表达占用，而不是「文件存在」：

        - 本函数打开锁文件时请求 FileAccess.ReadWrite，且只允许 FileShare.Read，
          因此第二个 winst 再想以同样方式打开就会被系统拒绝 —— 这就是互斥。
        - 允许 FileShare.Read 是为了让占用者信息可被读取：拿不到锁的一方
          仍能以只读方式打开文件，从而报出「正在运行的是哪个 PID」。
        - 进程被强杀时句柄由系统回收，锁不会残留成「永远在运行」，
          因此不需要超时 / 陈旧锁清理。

        取得的句柄必须一直持有到进程结束，否则锁会被提前释放：
        句柄存在 WinstInstanceLock 状态项里（静态字典持有引用，
        不会被 GC 回收掉句柄）。
    .PARAMETER Path
        锁文件路径，默认 Get-WinstInstanceLockPath。
    .OUTPUTS
        @{ Ok; Path; OwnerPid; OwnerPath; Error }
    #>
    param([string]$Path = '')

    if (-not $Path) { $Path = Get-WinstInstanceLockPath }

    $result = @{ Ok = $false; Path = $Path; OwnerPid = 0; OwnerPath = ''; Error = '' }

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        try { $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop } catch { }
    }

    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
    } catch {
        # 打不开 = 已有 winst 持有；顺手读出占用者信息用于提示
        $owner = Read-WinstInstanceLockInfo -Path $Path
        $result.OwnerPid = [int]$owner.Pid
        $result.OwnerPath = [string]$owner.Path
        $result.Error = $_.Exception.Message
        return $result
    }

    # 抢到了：把自己的信息写进去（仅供下一台机器 / 下一个进程诊断用）
    try {
        $selfPath = [string](Get-WinstState -Name WinstScriptPath)
        $lines = @(
            ('pid={0}' -f $PID)
            ('startedAt={0}' -f (Get-Date).ToString('s'))
            ('path={0}' -f $selfPath)
        )
        $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`r`n") + "`r`n")
        $stream.SetLength(0)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    } catch {
        # 写不进占用者信息不影响互斥本身：句柄已经拿到，锁就是成立的
    }

    # 句柄挂到状态里：局部变量被回收会让锁提前释放
    $null = Set-WinstState -Name WinstInstanceLock -Value $stream
    $result.Ok = $true
    return $result
}
