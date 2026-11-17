#Requires -Version 5.1

function Exit-WinstInstanceLock {
    <#
    .SYNOPSIS
        业务与暂存清理结束后释放数据目录锁和 Temp 锁，并删除锁文件。
    .DESCRIPTION
        进程被强杀时系统会自动回收句柄，残留文件不影响下次申请。
    #>
    param()

    $instanceLock = Get-WinstState -Name WinstInstanceLock
    if ($null -eq $instanceLock) { return }

    foreach ($stream in $instanceLock.Streams) {
        $path = $stream.Name
        try { $stream.Dispose() } catch { }
        try {
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        } catch { }
    }
    $null = Set-WinstState -Name WinstInstanceLock -Value $null
}
