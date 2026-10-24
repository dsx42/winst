#Requires -Version 5.1

function Get-WinstCachedListItems {
    <#
    .SYNOPSIS
        载入已下载包概览：先按索引确定展示项、按需刷新版本，再重建总览；空列表 / 失败时提示并等待回车。
    .OUTPUTS
        @{ Ok; Items }
    #>
    param([hashtable]$Context, [switch]$Silent)

    # 先用本地安装包索引确定要展示的软件，再按需刷新这些软件的版本信息（per-app TTL，--offline 自动
    # 跳过、展示集合全部有效时零解析，列表里的「可更新」标注才是当前值；
    # 没有已下载包时不做任何刷新
    $preview = Get-WinstCachedOverview -Context $Context
    $displayIds = @(Get-WinstDisplayIds -Items $(if ($preview.Ok) { $preview.Items } else { @() }))
    $refresh = Update-WinstDisplaySources -Context $Context -Ids $displayIds
    Write-WinstRefreshErrors -Errors $refresh.Errors

    $overview = Get-WinstCachedOverview -Context $Context
    if (-not $overview.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
        if (-not $Silent) {
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
        }
        return @{ Ok = $false; Items = @() }
    }
    if ($overview.Warning -and -not $Silent) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

    # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
    $items = @($overview.Items | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) {
        if ($Silent) {
            Write-Host ''
            Write-Host '  安装包位置里已经没有下载好的安装包了。' -ForegroundColor DarkGray
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
        } else {
            Write-Host ''
            Write-Host '  安装包位置里还没有下载好的安装包。' -ForegroundColor Yellow
            Write-Host ('  安装包位置: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel) -ForegroundColor DarkGray
            Write-Host '  安装或更新软件时会自动下载到这里，之后再回到本页就能看到并复用它们。' -ForegroundColor DarkGray
            Write-Host '  「仅下载」类型的软件下载软件包时也会放在这里。' -ForegroundColor DarkGray
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
        }
        return @{ Ok = $false; Items = @() }
    }
    return @{ Ok = $true; Items = $items }
}
