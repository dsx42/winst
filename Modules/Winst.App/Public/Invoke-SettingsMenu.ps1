#Requires -Version 5.1

function Invoke-SettingsMenu {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    $render = { param($ctx) Show-SettingsMenu -Context $ctx }
    $actions = @{
        '1' = {
            param($ctx)
            Invoke-PathSettingItem -Context $ctx -Key 'installRoot' -DisplayName '软件安装位置' `
                -CurrentDisplay $ctx.InstallRoot `
                -Hint '仅对此后的安装生效：已装软件留在旧位置继续可用（改完会列出旧位置里已有的软件目录）。安装记录跟着这个位置存放，新位置暂时是空的，进入「已装软件」时会自动扫描登记。已打开的终端需重开后才完全生效。'
        }
        '2' = {
            param($ctx)
            Invoke-PathSettingItem -Context $ctx -Key 'pkgDir' -DisplayName '安装包位置' `
                -CurrentDisplay $ctx.PkgDir `
                -Hint '立即生效；可指向 U 盘或网络共享目录。'
        }
        '3' = {
            param($ctx)
            Invoke-SettingItem -Context $ctx -Key 'proxy' -DisplayName '代理' `
                -CurrentDisplay (Format-ProxyDisplay -Value (Get-ConfigValue -Config $ctx.Config -Key 'proxy')) `
                -Hint '形如 http://127.0.0.1:7890；留空表示不使用代理。'
        }
        '4' = {
            param($ctx)
            $proxyAddress = Format-ProxyDisplay -Value (Get-ConfigValue -Config $ctx.Config -Key 'proxy')
            Invoke-SettingChoiceItem -Context $ctx -Key 'proxyMode' -DisplayName '代理模式' `
                -CurrentDisplay (Format-ProxyModeDisplay -Value (Get-ConfigValue -Config $ctx.Config -Key 'proxyMode')) `
                -Options @(
                    [ordered]@{ Value = 'auto';            Text = '自动';           Note = '先直连，连不上时再用代理重试' },
                    [ordered]@{ Value = 'download-direct'; Text = '下载直连优先'; Note = '下载先直连、失败再用代理；其它请求直接走代理' },
                    [ordered]@{ Value = 'always';          Text = '始终走代理';     Note = '每次都直接走代理，不做直连尝试' },
                    [ordered]@{ Value = 'off';             Text = '不使用代理';     Note = '只直连；填了代理地址也不使用' }
                ) `
                -Hint ('仅影响 winst 自己发起的下载 / 刷新；当前代理地址: {0}（没填地址时四种模式都不启用代理）。' -f $proxyAddress)
        }
        '5' = {
            param($ctx)
            Invoke-SettingChoiceItem -Context $ctx -Key 'pruneOldPackages' -DisplayName '下载后清理旧包' `
                -CurrentDisplay (Format-BoolDisplay -Value (Get-ConfigValue -Config $ctx.Config -Key 'pruneOldPackages')) `
                -Options @(
                    [ordered]@{ Value = $true;  Text = '开'; Note = '下载新版本成功后自动删掉这个软件的旧安装包，只留最新那份' },
                    [ordered]@{ Value = $false; Text = '关'; Note = '保留全部历史安装包，安装包位置会一直变大' }
                ) `
                -Hint '只影响「下载新版本时」的自动清理；要删掉已下载的安装包，请到「已下载包」里操作。'
        }
        '6' = {
            param($ctx)
            Invoke-SettingItem -Context $ctx -Key 'manifestTTLHours' -DisplayName '软件源刷新间隔' `
                -CurrentDisplay ('{0} 小时' -f (Get-ConfigValue -Config $ctx.Config -Key 'manifestTTLHours')) `
                -Validator { param($v) $n = 0; [int]::TryParse($v, [ref]$n) -and $n -ge 0 } `
                -Hint '单位为小时，例如 24。'
        }
        '7' = {
            param($ctx)
            Invoke-SettingChoiceItem -Context $ctx -Key 'updateFilesOnly' -DisplayName '更新方式' `
                -CurrentDisplay (Format-UpdateFilesOnlyDisplay -Value (Get-ConfigValue -Config $ctx.Config -Key 'updateFilesOnly')) `
                -Options @(
                    [ordered]@{ Value = $true;  Text = '只更新文件'; Note = '更新时环境变量 / PATH 保持原样，快捷方式只修正不新建；首次安装仍补齐缺失的' },
                    [ordered]@{ Value = $false; Text = '完整更新';   Note = '按软件源里的定义覆盖已存在的环境变量 / 快捷方式' }
                ) `
                -Hint '多个同族软件共存时（如 jdk8 / jdk21 / jdk25 都声明 JAVA_HOME）建议用「只更新文件」。'
        }
    }

    $result = Invoke-MenuLoop -Render $render -Context $Context `
        -Choices @('1', '2', '3', '4', '5', '6', '7', 'b', 'q') `
        -Actions $actions -CanGoBack
    if ($result -eq 'quit') { Set-WinstQuit }
}
