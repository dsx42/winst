#Requires -Version 5.1

function Suspend-WinstFluxTask {
    param([hashtable]$Service, [string]$Route)

    $null = Invoke-WinstFluxApi $Service PUT ($Route + '/pause')
    for ($poll = 0; $poll -lt 20; $poll++) {
        $task = Invoke-WinstFluxApi $Service GET $Route -Reconnect
        if ($task -and $task.status -in @(2,3,4)) { return $task }
        Start-Sleep -Milliseconds 250
    }
    throw '尚未确认任务停止写入'
}
