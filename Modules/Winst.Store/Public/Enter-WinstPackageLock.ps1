#Requires -Version 5.1

function Enter-WinstPackageLock {
    <#
    .SYNOPSIS
        锁定同一缓存根下的单个软件包。调用方在该包使用完毕后释放句柄。
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir, [Parameter(Mandatory = $true)][string]$Id)

    if (-not (Test-WinstSafePathSegment -Name $Id) -or (Test-WinstReservedPackageId -Id $Id)) { throw ('软件 id 不合法或使用了保留目录名：' + $Id) }
    $dir = Join-WinstPath $PkgDir '.winst-locks'
    $path = Join-WinstPath $dir $Id
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        Assert-WinstSafeWritePath -Path $dir -Directory
        $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
    }
    $stream = Open-WinstCacheLock -Path $path -Description '软件包锁'
    # 获得锁前计算的临时摘要和索引快照可能对应另一份文件。
    (Get-WinstState -Name WinstPackageHashCache).Clear()
    Clear-WinstJsonCache -Path (Get-WinstCacheIndexPath -PkgDir $PkgDir)
    return $stream
}