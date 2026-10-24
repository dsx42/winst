#Requires -Version 5.1

function Get-WinstRowRemoteFreshState {
    <#
    .SYNOPSIS
        取一行（最佳来源的解析锁）里记下的「远端新鲜度」结论：changed / unchanged / unknown；取不到返回空串。
    .DESCRIPTION
        versionFromPackage 条目在解析阶段会顺手发一次 HEAD 比对远端与缓存记账，结论存在解析锁的
        remoteFresh 字段里（见 New-ResolvedAppPlan）；列表 / 详情展示时读锁即可、零网络请求。
    #>
    param($Row)

    $chosen = Get-WinstRowBestPlanEntry -Row $Row
    if (-not $chosen -or -not $chosen['Plan']) { return '' }
    return ([string](Get-EntryString -Entry $chosen['Plan'] -Key 'remoteFresh'))
}
