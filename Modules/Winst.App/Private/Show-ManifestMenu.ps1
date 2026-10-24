#Requires -Version 5.1

function Show-ManifestMenu {
    <#
    .SYNOPSIS
        渲染「管理软件源」页：列出全部软件源，并说明三种输入（编号进详情、输入地址新建、a 刷新全部）。
    .DESCRIPTION
        与「管理安装清单」同一形态：没有单独的「添加 / 刷新 / 删除」菜单项。
        输入编号即进入该软件源的详情页，输入地址即新建软件源。
    .OUTPUTS
        @( <软件源> )——与列表编号一一对应
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    Show-Banner -Context $Context
    Write-Host ''
    Write-Host '  高级功能 · 管理软件源' -ForegroundColor Cyan
    Write-Host '' -ForegroundColor DarkGray

    $sources = @(Get-ManifestSourceList -Context $Context)
    if ($sources.Count -eq 0) {
        Write-Host '  （当前没有软件源）' -ForegroundColor DarkGray
    } else {
        for ($i = 0; $i -lt $sources.Count; $i++) {
            Write-ManifestSourceInfo -Context $Context -Source $sources[$i] -Index ($i + 1)
        }
    }

    Write-Host ''
    Write-Host '  输入编号 = 查看这个软件源的详情（可刷新 / 删除）' -ForegroundColor DarkGray
    Write-Host '  输入地址 = 新建软件源（GitHub 仓库或清单地址，可粘贴；输入 c 从剪贴板读取）' -ForegroundColor DarkGray
    Write-Host '  a = 刷新全部软件源' -ForegroundColor DarkGray
    Write-Host '  回车 / b = 返回，q = 退出程序' -ForegroundColor DarkGray
    Write-Host ''

    return @($sources)
}
