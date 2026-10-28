#Requires -Version 5.1

function Get-WinstCachedOverviewReady {
    <#
    .SYNOPSIS
        已下载包页面的公共前置：按索引确定展示项 → 按需刷新版本 → 重建总览。
    .DESCRIPTION
        菜单页（Get-WinstCachedListItems）与 CLI（winst list --cached）共用同一段准备逻辑：
        先把软件源里所有软件都解析一遍是浪费，因此只刷新索引里真正要展示的那些 id；
        没有已下载包时零解析。

        只准备数据，不打印页面：错误文案、空列表提示与「按回车返回」由调用方决定。
    .OUTPUTS
        @{ Ok; Error; Warning; Items }
    #>
    param([hashtable]$Context)

    $preview = Get-WinstCachedOverview -Context $Context
    $displayIds = @(Get-WinstDisplayIds -Items $(if ($preview.Ok) { $preview.Items } else { @() }))
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $displayIds
    Write-WinstRefreshErrors -Errors $refresh.Errors

    $overview = Get-WinstCachedOverview -Context $Context
    if (-not $overview.Ok) {
        return @{ Ok = $false; Error = [string]$overview.Error; Warning = ''; Items = @() }
    }

    # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
    $items = @($overview.Items | Where-Object { $null -ne $_ })
    return @{ Ok = $true; Error = ''; Warning = [string]$overview.Warning; Items = $items }
}
