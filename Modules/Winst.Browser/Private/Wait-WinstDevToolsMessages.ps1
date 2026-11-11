#Requires -Version 5.1

function Wait-WinstDevToolsMessages {
    <#
    .SYNOPSIS
        空转一段时间，把期间到达的 DevTools 事件收进会话（用于「点完按钮等一下下载事件」）。
    #>
    param($Session, [int]$Milliseconds)

    $deadline = [DateTime]::UtcNow.AddMilliseconds((Get-WinstBrowserRemainingMs -Session $Session -LimitMs $Milliseconds))
    while ($true) {
        $remaining = [int]($deadline - [DateTime]::UtcNow).TotalMilliseconds
        if ($remaining -le 0) { return }

        $raw = ''
        $raw = Receive-WinstDevToolsMessage -Session $Session -TimeoutMs $remaining
        if (-not $raw) { return }

        Add-WinstDevToolsEvent -Session $Session -Raw $raw
    }
}
