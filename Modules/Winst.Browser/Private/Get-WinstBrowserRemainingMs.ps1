#Requires -Version 5.1

function Get-WinstBrowserRemainingMs {
    <#
    .SYNOPSIS
        取浏览器整体截止时间内的剩余额度；耗尽后停止发送命令和点击。
    #>
    param($Session, [datetime]$Deadline = [datetime]::MaxValue, [int]$LimitMs = 20000, [switch]$Cleanup)

    if ($Session -and $Session.ContainsKey('Deadline') -and $Session.Deadline -lt $Deadline) { $Deadline = $Session.Deadline }
    $remaining = [Math]::Min([double]$LimitMs, ($Deadline - [datetime]::UtcNow).TotalMilliseconds)
    if ($remaining -le 0) {
        if ($Cleanup) { return 1 }
        throw '浏览器操作已达到整体超时限制'
    }
    return [Math]::Max(1, [int][Math]::Floor($remaining))
}
