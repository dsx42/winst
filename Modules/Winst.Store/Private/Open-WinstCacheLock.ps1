#Requires -Version 5.1

function Open-WinstCacheLock {
    <#
    .SYNOPSIS
        取得缓存锁句柄。锁被占用时短暂等待，其余错误直接报告。
    #>
    param([string]$Path, [string]$Description)

    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        try {
            Assert-WinstSafeWritePath -Path $Path
            return [IO.File]::Open($Path, 'OpenOrCreate', 'ReadWrite', 'Read')
        } catch {
            $code = $_.Exception.GetBaseException().HResult -band 0xffff
            if ($code -notin @(32, 33)) { throw }
            if ($timer.ElapsedMilliseconds -ge 10000) { throw ('等待{0}超时：{1}' -f $Description, $Path) }
            Start-Sleep -Milliseconds 50
        }
    }
}