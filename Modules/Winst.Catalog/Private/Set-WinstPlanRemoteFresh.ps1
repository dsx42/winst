#Requires -Version 5.1

function Set-WinstPlanRemoteFresh {
    <#
    .SYNOPSIS
        解析时记下「远端是否比缓存里的包更新」（remoteFresh），供列表 / 详情零网络展示。
    #>
    param($Plan, [string]$PkgDir = '', [hashtable]$Context = $null)

    $fresh = Get-WinstRemoteFreshnessHint -Context $Context -PkgDir $PkgDir -Id ([string](Get-EntryString -Entry $Plan -Key 'id')) -Plan $Plan
    $Plan['remoteFresh'] = [string]$fresh.State
}
