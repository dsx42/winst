#Requires -Version 5.1

function Invoke-AdvancedMenu {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    # 说明：不提供「修复安装记录」入口——进入「已装软件」时会自动刷新一次安装记录
    # ；命令行侧仍保留 `winst repair` 以便脚本化调用。
    $render = { param($ctx) Show-AdvancedMenu -Context $ctx }
    $actions = @{
        '1' = { param($ctx) Invoke-ManifestManager -Context $ctx }
        '2' = { param($ctx) Invoke-WinstListManager -Context $ctx }
        '3' = { param($ctx) $null = Invoke-WinstPack -Context $ctx }
    }

    # '1' / '2' 会进入子菜单：子菜单返回后直接重绘本菜单，不追加「按回车返回菜单」
    $result = Invoke-MenuLoop -Render $render -Context $Context `
        -Choices @('1', '2', '3', 'b', 'q') `
        -Actions $actions -NavigationChoices @('1', '2') -CanGoBack
    if ($result -eq 'quit') { Set-WinstQuit }
}
