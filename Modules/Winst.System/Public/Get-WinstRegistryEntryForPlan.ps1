#Requires -Version 5.1

function Get-WinstRegistryEntryForPlan {
    <#
    .SYNOPSIS
        按条目的名称规则，从系统安装记录（注册表卸载项）里选出唯一一条记录；选不中返回 $null。
    .DESCRIPTION
        与版本检测共用产品分组及改写规则，从可检测的产品记录中选版本最高的一条；
        没有任何可读版本时，使用查询结果中的首条记录。
        名称规则优先 detect.name，未声明时按条目名称推导（与修复安装记录一致）。

        全部命中的记录见 Get-WinstRegistryEntriesForPlan（同一软件可能同时存在新旧两版的多条记录）。
    #>
    param($Plan, [string]$InstallDir = '')

    $versions = @(Get-WinstRegistryVersionEntries -Plan $Plan -InstallDir $InstallDir)
    $best = $null
    foreach ($item in $versions) {
        if ($null -eq $best -or (Compare-WinstVersion -A ([string]$item.CompareVersion) -B ([string]$best.CompareVersion)) -gt 0) { $best = $item }
    }
    if ($null -ne $best) { return $best.Entry }
    $hits = @(Get-WinstRegistryEntriesForPlan -Plan $Plan -InstallDir $InstallDir)
    if ($hits.Count -eq 0) { return $null }
    return $hits[0]
}
