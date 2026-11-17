#Requires -Version 5.1

function Write-WinstInstanceBusyMessage {
    <#
    .SYNOPSIS
        已有 winst 在运行时打印的提示（说明原因与可选做法）。
    #>
    param(
        [Parameter(Mandatory = $true)]$Instance
    )

    if (-not (Get-EntryBool -Entry $Instance -Key 'Busy')) {
        Write-Host ('  无法取得单实例锁，本次启动已退出：{0}' -f (Get-EntryString -Entry $Instance -Key 'Error')) -ForegroundColor Red
        Write-Host ('  请检查锁文件路径的权限与磁盘状态：{0}' -f $Instance.LockPath) -ForegroundColor Gray
        return
    }
    Write-Host ''
    Write-Host '  已经有一个 winst 正在运行，本次启动已退出。' -ForegroundColor Yellow
    Write-Host '  另一个实例正在使用相同的数据目录或临时目录，请等待它结束，避免安装记录或暂存文件被覆盖。' -ForegroundColor Gray

    $pidText = [int]$Instance.OwnerPid
    if ($pidText -gt 0) {
        $detail = ('  正在运行的进程: PID {0}' -f $pidText)
        if ([string]$Instance.OwnerStartedAt) { $detail += ('（启动于 {0}）' -f [string]$Instance.OwnerStartedAt) }
        Write-Host $detail -ForegroundColor Gray
    }
    if ([string]$Instance.OwnerPath) {
        Write-Host ('  它运行的是   : {0}' -f [string]$Instance.OwnerPath) -ForegroundColor Gray
    }

    Write-Host ''
    Write-Host '  请先在那个窗口里结束操作（或关闭它），再重新启动。' -ForegroundColor Gray
    Write-Host ('  只读的查询（-v / --version / help）不受此限制。') -ForegroundColor DarkGray
}
