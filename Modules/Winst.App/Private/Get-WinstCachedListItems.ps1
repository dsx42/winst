#Requires -Version 5.1

function Get-WinstCachedListItems {
    <#
    .SYNOPSIS
        载入已下载包概览：先按索引确定展示项、按需刷新版本，再重建总览；空列表 / 失败时提示并等待回车。
    .OUTPUTS
        @{ Ok; Items }
    #>
    param([hashtable]$Context, [switch]$Silent)

    # 展示项、按需刷新与总览重建都在 Get-WinstCachedOverviewReady 里（与 CLI 同一段逻辑）
    $ready = Get-WinstCachedOverviewReady -Context $Context
    if (-not $ready.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $ready.Error) -ForegroundColor Red
        if (-not $Silent) {
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回主菜单 …'
        }
        return @{ Ok = $false; Items = @() }
    }
    if ($ready.Warning -and -not $Silent) { Write-Host ('  提示: {0}' -f $ready.Warning) -ForegroundColor Yellow }

    $items = @($ready.Items)
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
