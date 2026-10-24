#Requires -Version 5.1

function Get-ManifestResolvedApp {
    <#
    .SYNOPSIS
        按 id 读取某软件源的解析锁条目；未命中返回 $null。
    #>
    param([string]$PkgDir, [string]$Name, [string]$Id)

    if (-not $Id) { return $null }
    foreach ($app in @(Get-ManifestResolvedApps -PkgDir $PkgDir -Name $Name)) {
        if ((Get-EntryString -Entry $app -Key 'id') -ceq $Id) { return $app }
    }
    return $null
}
