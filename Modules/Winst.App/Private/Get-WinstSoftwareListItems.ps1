#Requires -Version 5.1

function Get-WinstSoftwareListItems {
    <#
    .SYNOPSIS
        载入软件源概览并过滤空条目；空列表 / 失败时打印原因并等待回车。
    .OUTPUTS
        @{ Ok; Items }
    #>
    param([hashtable]$Context, [switch]$Silent, [string]$EmptyText = '  软件源里还没有任何软件。')

    $overview = Get-WinstSoftwareOverview -Context $Context
    if (-not $overview.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
        Write-Host ''
        Read-WinstPause -Text '  按回车键返回主菜单 …'
        return @{ Ok = $false; Items = @() }
    }
    if ($overview.Warning -and -not $Silent) { Write-Host ('  提示: {0}' -f $overview.Warning) -ForegroundColor Yellow }

    # Where-Object 过滤掉 $null 条目：列表函数一旦返回 $null，@() 会把它变成一个「空条目」→ 渲染时报错
    $items = @($overview.Items | Where-Object { $null -ne $_ })
    if ($items.Count -eq 0) {
        Write-Host ''
        Write-Host $EmptyText -ForegroundColor Yellow
        if (-not $Silent) {
            Write-Host '  可以到「高级功能 → 管理软件源」刷新软件源后再来查看。' -ForegroundColor DarkGray
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
        }
        return @{ Ok = $false; Items = @() }
    }
    return @{ Ok = $true; Items = $items }
}
