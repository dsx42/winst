#Requires -Version 5.1

function Exit-WinstInstanceLock {
    <#
    .SYNOPSIS
        释放单进程锁（关闭句柄，并把锁文件删掉）。
    .DESCRIPTION
        正常退出时调用；进程被强杀时系统会自动回收句柄，
        锁文件留着也不会让下一个 winst 被挡住（能否独占打开才是判据）。
        删除文件只是让数据目录保持干净。
    #>
    param()

    $stream = Get-WinstState -Name WinstInstanceLock
    if ($null -eq $stream) { return }

    $path = Get-WinstInstanceLockPath
    try { $stream.Dispose() } catch { }
    $null = Set-WinstState -Name WinstInstanceLock -Value $null

    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}
