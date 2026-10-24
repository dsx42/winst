#Requires -Version 5.1

function Show-SettingsMenu {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    $config = $Context.Config

    Show-Banner -Context $Context
    Write-Host ''
    Write-Host '  设置' -ForegroundColor Cyan
    Write-Host ''
    Write-MenuItem -Key '1' -Label '软件安装位置'   -Description ('当前: {0}  {1}' -f $Context.InstallRoot, $Context.InstallRootLabel)
    Write-MenuItem -Key '2' -Label '安装包位置'     -Description ('当前: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel)
    Write-MenuItem -Key '3' -Label '代理'           -Description ('当前: {0}  {1}' -f (Format-ProxyDisplay -Value (Get-ConfigValue -Config $config -Key 'proxy')), (Get-ConfigTag -Context $Context -Key 'proxy'))
    Write-MenuItem -Key '4' -Label '代理模式'       -Description ('当前: {0}  {1}' -f (Format-ProxyModeDisplay -Value (Get-ConfigValue -Config $config -Key 'proxyMode')), (Get-ConfigTag -Context $Context -Key 'proxyMode'))
    Write-MenuItem -Key '5' -Label '下载后清理旧包' -Description ('当前: {0}  {1}' -f (Format-BoolDisplay -Value (Get-ConfigValue -Config $config -Key 'pruneOldPackages')), (Get-ConfigTag -Context $Context -Key 'pruneOldPackages'))
    Write-MenuItem -Key '6' -Label '软件源刷新间隔' -Description ('当前: {0} 小时  {1}' -f (Get-ConfigValue -Config $config -Key 'manifestTTLHours'), (Get-ConfigTag -Context $Context -Key 'manifestTTLHours'))
    Write-MenuItem -Key '7' -Label '更新方式'       -Description ('当前: {0}  {1}' -f (Format-UpdateFilesOnlyDisplay -Value (Get-ConfigValue -Config $config -Key 'updateFilesOnly')), (Get-ConfigTag -Context $Context -Key 'updateFilesOnly'))
    Write-MenuItem -Key 'b' -Label '返回'
    Write-MenuItem -Key 'q' -Label '退出'
    Write-Host ''
}
