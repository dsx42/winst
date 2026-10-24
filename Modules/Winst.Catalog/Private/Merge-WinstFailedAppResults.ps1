#Requires -Version 5.1

function Merge-WinstFailedAppResults {
    <#
    .SYNOPSIS
        本次检测失败的软件不覆盖已有成功结果：保留上次成功条目（备注写明原因）。
    .OUTPUTS
        @{ Apps; Succeeded; Failed; Retained; Reasons }
    #>
    param($Apps, $Meta, [int]$Failed, [int]$Succeeded)

    $apps = @($Apps)
    $retained = 0
    $retainedReasons = @()
    if ($Failed -le 0 -or -not $Meta -or -not $Meta.HasApps) {
        return @{ Apps = $apps; Succeeded = $Succeeded; Failed = $Failed; Retained = 0; Reasons = @() }
    }

    $previous = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal)
    foreach ($oldApp in @($Meta.Apps)) {
        $oldId = Get-EntryString -Entry $oldApp -Key 'id'
        if ($oldId) { $previous[$oldId] = $oldApp }
    }
    if ($previous.Count -eq 0) {
        return @{ Apps = $apps; Succeeded = $Succeeded; Failed = $Failed; Retained = 0; Reasons = @() }
    }

    $merged = @()
    foreach ($app in $apps) {
        $id = Get-EntryString -Entry $app -Key 'id'
        $isOk = Get-EntryBool -Entry $app -Key 'ok'
        if (-not $isOk -and $id -and $previous.ContainsKey($id) -and (Get-EntryBool -Entry $previous[$id] -Key 'ok')) {
            $oldApp = $previous[$id]
            $reason = Get-EntryString -Entry $app -Key 'error'
            $kept = Copy-WinstObjectShallow -InputObject $oldApp
            $notes = @(Get-EntryArray -Entry $oldApp -Key 'notes')
            $notes += ('本次刷新检测失败（{0}），已保留上次成功结果' -f $reason)
            $kept['notes'] = @($notes)
            # 保留的是旧结果，但「本次已尝试解析」要记进 per-app resolvedAt：
            # 否则旧条目（无 resolvedAt / 时间戳已过期）会被按需刷新每次都当过期重试
            $kept['resolvedAt'] = (Get-Date).ToString('s')
            $merged += $kept
            $retained++
            $retainedReasons += ('{0}: {1}' -f (Get-EntryString -Entry $app -Key 'name'), $reason)
            Write-Host ('    ! {0} 本次检测失败，已保留上次成功结果（{1}）' -f (Get-EntryString -Entry $app -Key 'name'), $reason) -ForegroundColor Yellow
        } else {
            $merged += $app
        }
    }

    return @{
        Apps      = $merged
        Succeeded = ($Succeeded + $retained)
        Failed    = ($Failed - $retained)
        Retained  = $retained
        Reasons   = @($retainedReasons)
    }
}
