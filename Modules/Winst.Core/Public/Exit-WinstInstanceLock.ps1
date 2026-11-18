#Requires -Version 5.1

function Exit-WinstInstanceLock {
    <#
    .SYNOPSIS
        业务与暂存清理结束后释放数据目录锁和 Temp 锁。
    .DESCRIPTION
        进程被强杀时系统会自动回收句柄，下一实例复用这两个锁文件。
    #>
    param()

    $instanceLock = Get-WinstState -Name WinstInstanceLock
    if ($null -eq $instanceLock) { return }

    foreach ($stream in $instanceLock.Streams) {
        try { $stream.Dispose() } catch { }
    }
    $null = Set-WinstState -Name WinstInstanceLock -Value $null
}
