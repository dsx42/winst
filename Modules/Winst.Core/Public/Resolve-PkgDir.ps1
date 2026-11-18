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

    $optionPkg = Get-EntryString -Entry $Options -Key 'PkgDir'
    if ($optionPkg) {
        return @{ Path = (Expand-WinstPath -Path $optionPkg -Base $DataRoot); Source = 'param' }
    }
    if ($env:WINST_PKG_DIR -and $env:WINST_PKG_DIR.Trim()) {
        return @{ Path = (Expand-WinstPath -Path $env:WINST_PKG_DIR -Base $DataRoot); Source = 'env' }
    }

    # 脚本同目录存在 apps\ 即自动命中离线套件缓存（零配置）
    $scriptDir = Get-WinstState -Name WinstScriptDir
    if ($scriptDir) {
        $scriptApps = Join-WinstPath $scriptDir 'apps'
        if (Test-Path -LiteralPath $scriptApps -PathType Container) {
            return @{ Path = $scriptApps; Source = 'script' }
        }
    }

    $configured = Get-ConfigValue -Config $Config -Key 'pkgDir'
    $defaultPath = Join-WinstPath $DataRoot 'apps'
    if ($configured -and $configured -cne $defaultPath) {
        return @{ Path = (Expand-WinstPath -Path $configured -Base $DataRoot); Source = 'config' }
    }
    # 读取配置时已补齐默认值，只有值完全相同才需要区分显式配置与首次运行。
    if ($configured -and (Test-Path -LiteralPath (Join-WinstPath $DataRoot 'config.json') -PathType Leaf)) {
        return @{ Path = $defaultPath; Source = 'config' }
    }
    return @{ Path = $defaultPath; Source = 'default' }
}
