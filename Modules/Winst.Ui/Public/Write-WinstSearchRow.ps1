#Requires -Version 5.1

function Write-WinstSearchRow {
    <#
    .SYNOPSIS
        输出一条已准备好的搜索结果，不读取台账或软件源。
    #>
    param($Item, [int]$Number)

    Write-WinstListItemIdentity -Item $Item -Number $Number
    if ($Item.InstalledVersion) {
        Write-Host ('    已安装 {0}' -f $Item.InstalledVersion) -NoNewline -ForegroundColor Green
        if ($Item.UpgradeHint) { Write-Host ('  {0}' -f $Item.UpgradeHint) -NoNewline -ForegroundColor Green }
    }
    Write-Host ''
    if ($Item.InstalledDir) { Write-Host ('     安装路径: {0}' -f $Item.InstalledDir) -ForegroundColor Gray }
    if ($Item.Type -eq 'download') { Write-Host '     类型: 只下载软件包，不安装到电脑（下载 / 更新软件包 / 删除软件包）' -ForegroundColor DarkGray }
    Write-Host ('     来源: {0}' -f $Item.SourceText) -ForegroundColor Gray
    if ($Item.Description) { Write-Host ('     说明: {0}' -f $Item.Description) -ForegroundColor DarkGray }
    Write-WinstCompanionVersions -Item $Item
}
