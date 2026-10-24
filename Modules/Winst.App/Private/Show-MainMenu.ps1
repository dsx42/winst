#Requires -Version 5.1

function Show-MainMenu {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    Show-Banner -Context $Context
    Write-Host ''
    Write-MenuItem -Key '1' -Label '安装软件'       -Description '搜索并安装，支持一次装多个'
    Write-MenuItem -Key '2' -Label '检查更新'       -Description '检查有没有新版本，并帮你更新'
    Write-MenuItem -Key '3' -Label '卸载软件'       -Description '从电脑上移除已安装的软件'
    Write-MenuItem -Key '4' -Label '已装软件'       -Description '查看已安装的软件，可更新/卸载'
    Write-MenuItem -Key '5' -Label '已下载包'       -Description '查看下载好的安装包，可安装/更新/删除'
    Write-MenuItem -Key '6' -Label '软件列表'       -Description '软件源里的全部软件，可安装/更新/卸载/删除安装包'
    Write-MenuItem -Key '7' -Label '一键安装'       -Description '按安装清单批量安装（重装系统后使用）'
    Write-MenuItem -Key '8' -Label '高级功能'       -Description '软件源、安装清单、U盘安装包'
    Write-MenuItem -Key '0' -Label '设置'           -Description '安装位置、安装包位置、代理等'
    Write-MenuItem -Key 'q' -Label '退出'
    Write-Host ''
}
