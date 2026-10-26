#Requires -Version 5.1

function Resolve-InstallRoot {
    <#
    .SYNOPSIS
        解析安装根目录：--install-root > WINST_INSTALL_ROOT > config.json > 默认值。
    #>
    param(
        [string]$DataRoot,
        [hashtable]$Options,
        [hashtable]$Config
    )

    if ($Options -and $Options.InstallRoot) {
        return (Expand-WinstPath -Path $Options.InstallRoot -Base $DataRoot)
    }
    if ($env:WINST_INSTALL_ROOT -and $env:WINST_INSTALL_ROOT.Trim()) {
        return (Expand-WinstPath -Path $env:WINST_INSTALL_ROOT -Base $DataRoot)
    }

    $configPath = Join-WinstPath $DataRoot 'config.json'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        # 只取一次配置值（原写法在条件与返回处各取一次）
        $configured = Get-ConfigValue -Config $Config -Key 'installRoot'
        if ($configured) { return (Expand-WinstPath -Path $configured -Base $DataRoot) }
    }

    return (Expand-WinstPath -Path '%USERPROFILE%\winst' -Base $DataRoot)
}
