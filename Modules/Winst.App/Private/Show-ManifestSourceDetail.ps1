#Requires -Version 5.1

function Show-ManifestSourceDetail {
    <#
    .SYNOPSIS
        渲染单个软件源的详情页：来源位置、清单版本、软件清单概况，以及可对这一个源做的操作。
    .DESCRIPTION
        内置源与本地清单不可删除，详情页据此只列刷新；删除项由调用方决定是否显示。
    .OUTPUTS
        @{ CanRefresh; CanRemove }——本页实际给出的操作
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $isLocal = Get-EntryBool -Entry $Source -Key 'isLocal'
    $isBuiltin = Get-EntryBool -Entry $Source -Key 'isBuiltin'
    $canRemove = (-not $isLocal) -and (-not $isBuiltin)

    Show-Banner -Context $Context
    Write-Host ''
    Write-Host '  高级功能 · 管理软件源 · 详情' -ForegroundColor Cyan
    Write-Host ''

    # 详情页不显示编号：这里只有这一个源，编号没有意义
    Write-ManifestSourceInfo -Context $Context -Source $Source -Index 0

    Write-Host ''
    Write-Host '  r) 刷新这个软件源（重新读取清单，获取各软件的可用版本；不会安装软件）' -ForegroundColor White
    if ($canRemove) {
        Write-Host '  d) 删除这个软件源（连同它的清单缓存）' -ForegroundColor White
    } elseif ($isBuiltin) {
        Write-Host '  内置软件源不可删除。' -ForegroundColor DarkGray
    } else {
        Write-Host '  本地清单不可在这里删除：请直接移走清单文件。' -ForegroundColor DarkGray
    }
    Write-Host '  回车 / b = 返回列表，q = 退出程序' -ForegroundColor DarkGray
    Write-Host ''

    return @{ CanRefresh = $true; CanRemove = $canRemove }
}
