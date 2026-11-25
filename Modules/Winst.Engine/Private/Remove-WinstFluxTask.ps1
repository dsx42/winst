#Requires -Version 5.1

function Remove-WinstFluxTask {
    param([hashtable]$Service, $Task, [string]$DestDir, [string]$FileName, $Record)

    # 重新下载前停止原任务，已完成的任务保留在桌面历史中。
    if ($Task -and $Task.status -ne 3) {
        $route = 'tasks/' + $Task.taskId
        if ($Task.status -notin @(2,4)) { $Task = Suspend-WinstFluxTask $Service $route }
        if ($Task.status -ne 3) { $null = Invoke-WinstFluxApi $Service DELETE ($route + '?deleteFiles=false') }
    }
    $workDir = Get-WinstFluxSaveDir $DestDir $FileName $Record
    if ($workDir -ne $DestDir) {
        Clear-WinstInstallDir -Dir $workDir -AllowedRoot $DestDir -Strict
    } else {
        foreach ($name in @($FileName, ($FileName + '.fdownloading'))) {
            $file = Join-Path $DestDir $name
            Assert-WinstSafeWritePath -Path $file
            if (Test-Path -LiteralPath $file -PathType Leaf) { Remove-Item -LiteralPath $file -Force -ErrorAction Stop }
        }
    }
    Remove-Item -LiteralPath (Get-WinstFluxTaskPath $DestDir $FileName) -ErrorAction Stop
}
