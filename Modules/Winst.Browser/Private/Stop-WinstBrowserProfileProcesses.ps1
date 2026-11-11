#Requires -Version 5.1

function Stop-WinstBrowserProfileProcesses {
    <#
    .SYNOPSIS
        结束 winst 专用 profile 的进程；退出码与重新查询均确认后才允许清理目录。
    #>
    param([string]$ProfileDir, [datetime]$Deadline = [datetime]::MaxValue)

    if (-not $ProfileDir) { return 0 }
    $leaf = Split-Path -Leaf $ProfileDir
    if ($leaf -notlike 'winst-browser-*' -and $leaf -notlike 'winst-cdp-*') { throw '拒绝清理非 winst 浏览器目录' }
    $query = {
        # shortcut: CIM 的秒级超时可能让清理略超截止时间，严格墙钟上限需独立清理进程。
        @(Get-CimInstance -ClassName Win32_Process -Filter "Name='msedge.exe'" -OperationTimeoutSec 1 -ErrorAction Stop |
            Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($ProfileDir, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    }
    $targets = @(& $query)
    $errors = @()
    foreach ($target in $targets) {
        $timeout = Get-WinstBrowserRemainingMs -Deadline $Deadline -LimitMs 1000 -Cleanup
        $run = Invoke-WinstCapturedCommand -FilePath (Join-WinstPath $env:SystemRoot 'System32\taskkill.exe') -Arguments ('/PID {0} /T /F' -f [int]$target.ProcessId) -TimeoutMs $timeout
        if (-not $run.Ok -or $run.TimedOut -or $null -eq $run.ExitCode -or $run.ExitCode -ne 0) {
            $errors += ('PID {0}（超时: {1}，退出码: {2}）' -f $target.ProcessId, $run.TimedOut, $run.ExitCode)
        }
    }
    $survivors = @(& $query)
    if ($survivors.Count -gt 0) { throw ('浏览器进程仍占用临时目录 {0}，目录已保留：{1}' -f $ProfileDir, ($errors -join '；')) }
    return $targets.Count
}
