#Requires -Version 5.1

function Get-WinstOwnedFluxTask {
    param([hashtable]$Service, $Record, [string]$DestDir, [string]$FileName)

    if (-not $Service -or $Record.address -cne $Service.Address -or
        $Record.computer -ne [Environment]::MachineName) { throw '请在原计算机连接原 FluxDown 管理服务' }
    $saveDir = Get-WinstFluxSaveDir $DestDir $FileName $Record
    $id = [string]$Record.taskId
    if (-not $id) {
        # 创建请求与写回 ID 之间中断。新建任务处于暂停状态，按其唯一暂存位置找回。
        $tasks = Invoke-WinstFluxApi $Service GET 'tasks' -Reconnect
        $found = @($tasks | Where-Object { $_ -and $_.saveDir -eq $saveDir -and ($Record.magnet -or $_.fileName -eq $FileName) })
        if ($found.Count -gt 1) { throw ('暂存路径对应多个任务，请在 FluxDown 核对：{0}' -f ($found.taskId -join '、')) }
        if ($found.Count -eq 0) { throw ('尚未按暂存位置找到已提交的任务，请在 FluxDown 核实：' + $saveDir) }
        $id = [string]$found[0].taskId
    }
    if (-not [guid]::TryParse($id, [ref]([guid]::Empty))) { throw '服务任务 ID 无效' }
    # 任务详情来自服务端快照，刚创建或重连时可能尚未看到原 ID。
    for ($poll = 0; $poll -lt 5; $poll++) {
        $task = Invoke-WinstFluxApi $Service GET ('tasks/' + $id) -Reconnect
        if ($task) { break }
        Start-Sleep -Milliseconds 250
    }
    if ($task -and ($task.taskId -ne $id -or $task.saveDir -ne $saveDir -or
        (-not $Record.magnet -and $task.fileName -ne $FileName))) {
        throw '服务任务的暂存位置与本次目标不符'
    }
    if (-not $task) {
        $info = Invoke-WinstFluxApi $Service GET 'info' -Reconnect
        if ($info.name -ne 'FluxDown') { throw '无法确认原服务的任务状态' }
    }
    return $task
}
