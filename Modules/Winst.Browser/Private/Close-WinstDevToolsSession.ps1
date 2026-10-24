#Requires -Version 5.1

function Close-WinstDevToolsSession {
    <#
    .SYNOPSIS
        结束无头浏览器会话：断开 WebSocket、结束整棵进程树、删掉临时用户数据目录。
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
    if ($Session.ProcessId) {
        # 连同下级进程一起结束
        try { $null = & taskkill.exe /PID $Session.ProcessId /T /F 2>&1 } catch { }
    }
    if ($Session.ProfileDir -and (Test-Path -LiteralPath $Session.ProfileDir)) {
        Clear-WinstInstallDir -Dir $Session.ProfileDir
    }
}
