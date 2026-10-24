#Requires -Version 5.1

function Show-AdvancedMenu {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    Show-Banner -Context $Context
    Write-Host ''
    Write-Host '  高级功能' -ForegroundColor Cyan
    Write-Host ''
    Write-MenuItem -Key '1' -Label '管理软件源'     -Description '添加 / 刷新 / 删除在线软件源'
    Write-MenuItem -Key '2' -Label '管理安装清单'   -Description '列出全部安装清单，可查看 / 编辑 / 删除 / 新建'
    Write-MenuItem -Key '3' -Label '制作U盘安装包'  -Description '把安装清单里的软件打包进U盘，供没有网络的电脑安装'
    Write-MenuItem -Key 'b' -Label '返回'
    Write-MenuItem -Key 'q' -Label '退出'
    Write-Host ''
}
