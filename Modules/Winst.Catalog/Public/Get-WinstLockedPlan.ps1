#Requires -Version 5.1

function Get-WinstLockedPlan {
    <#
    .SYNOPSIS
        从已刷新的软件清单（解析锁）里按 id 取条目，不额外联网；未命中返回 $null。
    .DESCRIPTION
        卸载相关的判断只用「已经刷新到本地的软件清单」：软件源被删掉也能照常卸载，
        不会因为在离线机器上卸载而卡在联网解析上。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Id
    )

    if (-not $Id) { return $null }
    foreach ($match in @(Get-ResolvedAppsById -Context $Context -Id $Id)) {
        $app = $match['App']
        if ($app -and (Get-EntryBool -Entry $app -Key 'ok')) { return $app }
    }
    return $null
}
