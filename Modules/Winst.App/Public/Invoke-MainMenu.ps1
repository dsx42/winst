#Requires -Version 5.1

function Invoke-MainMenu {
    $null = Set-WinstState -Name WinstQuitRequested -Value ($false)
    $null = Set-WinstState -Name WinstSkipMenuPause -Value ($false)
    # 从这里开始是交互式菜单：提示文案按菜单口径走（不出现「请加 --force」这类命令行开关，见 Test-WinstMenuMode）
    $null = Set-WinstState -Name WinstMenuMode -Value ($true)
    $context = New-WinstContext -Options (Get-WinstState -Name WinstOptions)

    $render = { param($ctx) Show-MainMenu -Context $ctx }
    $actions = @{
        '1' = { param($ctx) Invoke-InstallFlow -Context $ctx }
        '2' = { param($ctx) Invoke-UpdateCheck -Context $ctx }
        '3' = { param($ctx) Invoke-UninstallFlow -Context $ctx }
        '4' = { param($ctx) Invoke-InstalledList -Context $ctx }
        '5' = { param($ctx) Invoke-CacheList -Context $ctx }
        '6' = { param($ctx) Invoke-SoftwareList -Context $ctx }
        '7' = { param($ctx) Invoke-BundleInstall -Context $ctx }
        '8' = { param($ctx) Invoke-AdvancedMenu -Context $ctx }
        '0' = { param($ctx) Invoke-SettingsMenu -Context $ctx }
    }

    # '1' 安装软件 / '3' 卸载软件：流程自带输入循环，直接回车即结束回主菜单，不追加「按回车键返回菜单」
    # '4' 已装软件 / '5' 已下载包 / '6' 软件列表：列表里按 b 直接回主菜单，不要求按一次回车
    # '8' 高级功能 / '0' 设置 会进入子菜单：子菜单返回后直接重绘本菜单
    $null = Invoke-MenuLoop -Render $render -Context $context `
        -Choices @('1', '2', '3', '4', '5', '6', '7', '8', '0', 'q') `
        -Actions $actions -NavigationChoices @('4', '5', '6', '8', '0') -NoPauseChoices @('1', '3')
}
