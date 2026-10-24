#Requires -Version 5.1

function Write-WinstInstanceBusyMessage {
    <#
    .SYNOPSIS
        已有 winst 在运行时打印的提示（说明原因与可选做法）。
    #>
    param(
        [Parameter(Mandatory = $true)]$Instance
    )

    Write-Host ''
    Write-Host '  已经有一个 winst 正在运行，本次启动已退出。' -ForegroundColor Yellow
    Write-Host '  同时开两个 winst 会并发改写安装记录与安装包缓存，可能把记录写坏，因此只允许一个。' -ForegroundColor Gray

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
