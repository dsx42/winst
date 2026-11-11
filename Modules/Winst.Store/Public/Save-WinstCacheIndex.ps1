#Requires -Version 5.1

function Save-WinstCacheIndex {
    <#
    .SYNOPSIS
        持有共享索引锁后重读、修改并原子保存；修改块只更新本次涉及的条目。
    .DESCRIPTION
        锁位于包目录的 winst.json.lock，覆盖完整读改写过程；占用时等待，超时或无权限明确失败。
        锁文件保留，进程退出自动释放句柄；空修改块用于按当前目录校对索引。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$PkgDir,
        [Parameter(Mandatory = $true)][scriptblock]$Update
    )

    $path = Get-WinstCacheIndexPath -PkgDir $PkgDir
    $lockPath = $path + '.lock'
    Assert-WinstSafeWritePath -Path $lockPath
    if (-not (Test-Path -LiteralPath $PkgDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $PkgDir -Force -ErrorAction Stop
    }
    $stream = $null
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($null -eq $stream) {
            try {
                Assert-WinstSafeWritePath -Path $lockPath
                $stream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
            } catch {
                $code = $_.Exception.GetBaseException().HResult -band 0xffff
                if (@(32, 33) -notcontains $code) { throw }
                if ($timer.ElapsedMilliseconds -ge 10000) { throw ('等待缓存索引写入锁超时：{0}' -f $lockPath) }
                Start-Sleep -Milliseconds 50
            }
        }
        # 拿锁前的快照不能作为写入基线，即使远端文件戳恰好没有变化。
        Clear-WinstJsonCache -Path $path
        $read = Read-WinstCacheIndex -PkgDir $PkgDir
        if (-not $read.CanSave) { throw $read.BackupError }
        $index = $read.Index
        $null = & $Update $index
        Assert-WinstDistinctIds -Ids @($index.Keys)
        $null = Write-WinstJsonFileIfChanged -Path $path -InputObject $index -Depth 8
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}
