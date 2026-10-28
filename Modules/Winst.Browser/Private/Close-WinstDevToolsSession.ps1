#Requires -Version 5.1

function Close-WinstDevToolsSession {
    <#
    .SYNOPSIS
        结束无头浏览器会话：断开 WebSocket、结束整棵进程树、释放进程句柄、删掉临时用户数据目录。
    .DESCRIPTION
        结束进程优先按 profile 目录匹配（Stop-WinstBrowserProfileProcesses）：进程句柄拿到的 PID
        不一定是最终在跑的那个主进程（Edge 起新 profile 时会再拉起一个、最初那个先退出），按 PID 杀会漏掉
        真正的实例，残留进程一直占着 profile，下次抓页面就会「没有返回页面内容」。PID 再补一刀兜底。
        两路输出任务在进程结束后会立即完成，这里等一下就释放：留着任务与进程对象只会攒句柄。
    #>
    param($Session)

    if ($null -eq $Session) { return }
    try { if ($Session.Socket) { $Session.Socket.Dispose() } } catch { }
    try {
        if ($Session.TokenSource) {
            $Session.TokenSource.Cancel()
            $Session.TokenSource.Dispose()
        }
    } catch { }
    if ($Session.ProfileDir) {
        $null = Stop-WinstBrowserProfileProcesses -ProfileDir ([string]$Session.ProfileDir)
    }
    if ($Session.ProcessId) {
        # 连同下级进程一起结束（ProfileDir 匹配不到时的兜底）
        try { $null = & taskkill.exe /PID $Session.ProcessId /T /F 2>&1 } catch { }
    }
    # 浏览器已结束，两路读取任务随之完成：等一下就释放（内容不在成功路径上用）
    if ($Session.StdoutTask) { try { $null = $Session.StdoutTask.Wait(1000) } catch { } }
    if ($Session.StderrTask) { try { $null = $Session.StderrTask.Wait(1000) } catch { } }
    if ($Session.Process) { try { $Session.Process.Dispose() } catch { } }
    if ($Session.ProfileDir -and (Test-Path -LiteralPath $Session.ProfileDir)) {
        Clear-WinstInstallDir -Dir $Session.ProfileDir
    }
}
