#Requires -Version 5.1

function Remove-WinstFluxTask {
    param([hashtable]$Service, $Task, [string]$DestDir, [string]$FileName, $Record)

    if ($Task -and $Task.status -ne 3) {
        $route = 'tasks/' + $Task.taskId
        if ($Task.status -notin @(2,4)) { $Task = Suspend-WinstFluxTask $Service $route }
        if ($Task.status -ne 3) { $null = Invoke-WinstFluxApi $Service DELETE ($route + '?deleteFiles=false') }
    }
    $dir = Get-WinstFluxSaveDir $DestDir $FileName $Record
    # 每次转存使用独立目录，替代文件登记成功后再清除。
    $replaced = Join-Path $DestDir '.tasks\replaced'
    $previous = Join-Path $replaced ([guid]::NewGuid().ToString('N'))
    Assert-WinstSafeWritePath -Path $previous -Directory
    if ($dir -eq $DestDir) {
        # 共享暂存目录还可能含有其他任务，只转存本任务的文件。
        foreach ($name in @($FileName, ($FileName + '.fdownloading'))) {
            $file = Join-Path $dir $name
            Assert-WinstSafeWritePath -Path $file
            if (Test-Path -LiteralPath $file -PathType Leaf -ErrorAction Stop) {
                $null = New-Item -ItemType Directory -Path $previous -Force -ErrorAction Stop
                Move-Item -LiteralPath $file -Destination $previous -ErrorAction Stop
            }
        }
    } elseif (Test-Path -LiteralPath $dir -PathType Container -ErrorAction Stop) {
        if (Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop | Select-Object -First 1) {
            $null = New-Item -ItemType Directory -Path $replaced -Force -ErrorAction Stop
            [IO.Directory]::Move($dir, $previous)
        } else {
            # 非递归删除；外部进程新写入的内容会使本次删除失败。
            [IO.Directory]::Delete($dir, $false)
        }
    }
    Set-WinstDownloadTaskRecord $DestDir $FileName $null
}
