#Requires -Version 5.1

function Get-WinstLockedPlan {
    <#
    .SYNOPSIS
        从安装来源的解析锁里按 id 取条目；来源缺失或未命中返回 $null，不额外联网。
    .DESCRIPTION
        卸载相关的判断只用「已经刷新到本地的软件清单」：软件源被删掉也能照常卸载，
        不会因为在离线机器上卸载而卡在联网解析上。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Id,
        [string]$SourceName
    )

    if (-not $Id -or -not $SourceName) { return $null }
    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        if ([string]$source['name'] -cne $SourceName) { continue }
        $app = Get-ManifestResolvedApp -PkgDir $Context.PkgDir -Name $SourceName -Id $Id
        if ($app -and (Get-EntryBool -Entry $app -Key 'ok')) { return $app }
    }
    return $null
}
