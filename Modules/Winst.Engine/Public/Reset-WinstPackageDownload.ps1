#Requires -Version 5.1

function Reset-WinstPackageDownload {
    param([string]$DestDir, [string]$FileName, $Config)

    $path = Get-WinstFluxTaskPath $DestDir $FileName
    $failedDir = Join-Path (Join-Path (Join-Path $DestDir '.local') $FileName) 'failed'
    Clear-WinstInstallDir -Dir $failedDir -AllowedRoot $DestDir -Strict
    if (-not (Test-Path -LiteralPath $path)) { return }
    $record = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

    try {
        if (-not $record.address -or $record.computer -ne [Environment]::MachineName) { throw '请在原计算机连接原管理服务' }
        $service = Get-WinstFluxService -Config $Config -Address $record.address -Reconnect
        $task = Get-WinstOwnedFluxTask $service $record $DestDir $FileName
        Remove-WinstFluxTask $service $task $DestDir $FileName $record
    } catch { throw ('无法释放 FluxDown 任务 {0}，已保留 {1}：{2}' -f $record.taskId, $path, $_.Exception.Message) }
}
