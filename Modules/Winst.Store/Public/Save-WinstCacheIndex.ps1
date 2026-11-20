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
        [Parameter(Mandatory = $true)][scriptblock]$Update,
        [string[]]$UpdateIds
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
        $stored = $null
        $read = Read-WinstCacheIndex -PkgDir $PkgDir -StoredValue ([ref]$stored)
        if (-not $read.CanSave) { throw $read.Error }
        $index = $read.Index
        if ($PSBoundParameters.ContainsKey('UpdateIds')) {
            $selected = New-WinstOrdinalDictionary
            $allowed = New-WinstOrdinalDictionary
            foreach ($id in $UpdateIds) {
                if (-not (Test-WinstSafePathSegment -Name $id) -or (Test-WinstReservedPackageId -Id $id)) {
                    throw ('无效的索引条目：{0}' -f $id)
                }
                $allowed[$id] = $true
                if ($index.Contains($id)) { $selected[$id] = $index[$id] }
            }
            $null = & $Update $selected
            foreach ($id in $selected.Keys) {
                if (-not $allowed.Contains($id)) { throw ('索引修改超出指定条目：{0}' -f $id) }
            }
            $changed = $read.Changed -or $null -eq $stored
            foreach ($id in $allowed.Keys) {
                $prior = $null
                if ($null -ne $stored) { $prior = $stored.PSObject.Properties[$id] }
                if ($selected.Contains($id)) {
                    $index[$id] = $selected[$id]
                    if (-not $changed) {
                        $changed = -not $prior -or $prior.Name -cne $id -or -not (Test-WinstJsonValueEqual -Left $prior.Value -Right $selected[$id])
                    }
                } else {
                    $index.Remove($id)
                    if ($prior -and $prior.Name -ceq $id) { $changed = $true }
                }
            }
        } else {
            $null = & $Update $index
            $changed = $null -eq $stored -or -not (Test-WinstJsonValueEqual -Left $stored -Right $index)
        }
        Assert-WinstDistinctIds -Ids @($index.Keys)
        if ($changed) {
            Write-FileAtomic -Path $path -Content (ConvertTo-WinstJson -InputObject $index -Depth 8)
        } else {
            # 即使无需落盘，锁内重读也可能看到了同戳的外部更新。
            Clear-WinstJsonCache -Path $path
        }
    } catch {
        if ($null -ne $stream) { Clear-WinstJsonCache -Path $path }
        throw
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}
