#Requires -Version 5.1

function Resolve-PkgDir {
    <#
    .SYNOPSIS
        解析软件包缓存目录：--pkg-dir > WINST_PKG_DIR > 脚本同目录 apps\ > config.json > 默认值。
    .OUTPUTS
        @{ Path = <路径>; Source = param|env|script|config|default }
    #>
    param(
        [string]$DataRoot,
        [hashtable]$Options,
        [hashtable]$Config
    )

    if ($Options -and $Options.PkgDir) {
        return @{ Path = (Expand-WinstPath -Path $Options.PkgDir -Base $DataRoot); Source = 'param' }
    }
    if ($env:WINST_PKG_DIR -and $env:WINST_PKG_DIR.Trim()) {
        return @{ Path = (Expand-WinstPath -Path $env:WINST_PKG_DIR -Base $DataRoot); Source = 'env' }
    }

    # 脚本同目录存在 apps\ 即自动命中离线套件缓存（零配置）
    if ((Get-WinstState -Name WinstScriptDir)) {
        $scriptApps = Join-Path (Get-WinstState -Name WinstScriptDir) 'apps'
        if (Test-Path -LiteralPath $scriptApps -PathType Container) {
            return @{ Path = $scriptApps; Source = 'script' }
        }
    }

    $configPath = Join-Path $DataRoot 'config.json'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        # 只取一次配置值（原写法在条件与返回处各取一次）
        $configured = Get-ConfigValue -Config $Config -Key 'pkgDir'
        if ($configured) { return @{ Path = (Expand-WinstPath -Path $configured -Base $DataRoot); Source = 'config' } }
    }

    return @{ Path = (Join-Path $DataRoot 'apps'); Source = 'default' }
}
