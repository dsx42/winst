#Requires -Version 5.1

function Remove-WinstObsoleteDownloadRecord {
    # 新计划的文件已改名。只解除已停止任务的绑定，保留下载过的内容。
    param([string]$DestDir, [string]$FileName, $Record, $Config)

    try {
        $task = $null
        $service = $null
        if ((Get-EntryString $Record 'mode') -ne 'local') {
            if (-not $Record.address -or $Record.computer -ne [Environment]::MachineName) { throw '请在原计算机连接原管理服务' }
            $service = Get-WinstFluxService -Config $Config -Address $Record.address -Reconnect
            $task = Get-WinstOwnedFluxTask $service $Record $DestDir $FileName
            if ($task -and $task.status -notin @(2,3,4)) { throw '任务仍在运行' }
        }
        Remove-WinstFluxTask $service $task $DestDir $FileName $Record
        return $true
    } catch {
        Write-Warning ('保留 {0} 的旧下载记录：{1}' -f $FileName, $_.Exception.Message)
        return $false
    }
}
