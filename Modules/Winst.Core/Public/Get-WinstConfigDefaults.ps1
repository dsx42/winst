#Requires -Version 5.1

function Get-WinstConfigDefaults {
    <#
    .SYNOPSIS
        返回内置默认配置（config.json 缺键时使用的取值）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataRoot
    )

    return @{
        installRoot      = '%USERPROFILE%\winst'
        pkgDir           = (Join-WinstPath $DataRoot 'apps')
        pruneOldPackages = $true
        manifestTTLHours = 24
        proxy            = ''
        proxyMode        = 'auto'
        # 已登记软件更新 / 重装时跳过环境变量与 PATH，避免改写同族软件的共享变量；
        # 已存在的快捷方式仍校验并修正。首次安装补齐缺失项。
        updateFilesOnly  = $true
    }
}
