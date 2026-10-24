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
        pkgDir           = (Join-Path $DataRoot 'apps')
        pruneOldPackages = $true
        manifestTTLHours = 24
        proxy            = ''
        proxyMode        = 'auto'
        # 更新时只更新文件：更新 / 重装已登记软件时**完全不动**环境变量 /
        # PATH 项 / 快捷方式——多个同族软件共存时（如 jdk8 / jdk21 / jdk25 都声明 JAVA_HOME），
        # 更新其中一个不会把共享变量改写成它。默认开启，可在「设置」里关掉（改为完整更新）；
        # 首次安装不受这条影响（新装软件该有的环境变量 / 快捷方式照常补齐）。
        updateFilesOnly  = $true
    }
}
