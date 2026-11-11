#Requires -Version 5.1

function Close-WinstDevToolsSession {
    <#
    .SYNOPSIS
        释放协议资源；确认 profile 进程退出后清理目录，失败保留目录与清理错误。
    #>
    param($Session)

    if ($null -eq $Session) { return }
    try { if ($Session.Socket) { $Session.Socket.Dispose() } } catch { }
    try {
        if ($Session.TokenSource) { $Session.TokenSource.Cancel(); $Session.TokenSource.Dispose() }
    } catch { }
    if ($Session.ProfileDir) {
        try {
            $null = Stop-WinstBrowserProfileProcesses -ProfileDir $Session.ProfileDir -Deadline $Session.Deadline
            if (Test-Path -LiteralPath $Session.ProfileDir) { Clear-WinstInstallDir -Dir $Session.ProfileDir }
            if (Test-Path -LiteralPath $Session.ProfileDir) { throw '临时目录未能删除' }
            $Session.ProfileDir = ''
        } catch { $Session.CleanupError = ('浏览器清理失败：{0}' -f $_.Exception.Message) }
    }
    if ($Session.Process) { try { $Session.Process.Dispose() } catch { } }
}
