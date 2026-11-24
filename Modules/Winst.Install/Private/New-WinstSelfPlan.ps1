#Requires -Version 5.1

function New-WinstSelfPlan {
    <#
    .SYNOPSIS
        为本地安装包提供登记台账和创建快捷方式所需的软件定义。
    #>
    return [ordered]@{
        name      = 'winst'
        type      = 'portable'
        install   = [ordered]@{ method = 'portable'; mainExe = 'winst.cmd' }
        shortcuts = [ordered]@{ desktop = $true; startMenu = $true }
        uninstall = [ordered]@{ method = 'portable-dir' }
    }
}
