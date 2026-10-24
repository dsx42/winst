#Requires -Version 5.1

function Get-ConfigTag {
    <#
    .SYNOPSIS
        返回配置项按实际来源的标记：内置默认 → [默认]，用户改过 → [自定义]。
    .DESCRIPTION
        路径类配置还有优先级更高的临时来源，按实际生效者标注：
        [参数]（命令行）/ [环境变量] / [U盘]（脚本同目录 apps\）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    # 选项对象可能是 hashtable 或 PSCustomObject：统一按「键是否存在」取值，
    # 避免 Set-StrictMode -Version 2 下访问不存在的成员抛异常
    $options = Get-WinstState -Name WinstOptions
    $optionInstallRoot = [string](Get-EntryString -Entry $options -Key 'InstallRoot')
    $optionPkgDir = [string](Get-EntryString -Entry $options -Key 'PkgDir')

    if ($Key -eq 'installRoot') {
        if ($optionInstallRoot) { return '[参数]' }
        if ($env:WINST_INSTALL_ROOT -and $env:WINST_INSTALL_ROOT.Trim()) { return '[环境变量]' }
        $current = Get-ConfigValue -Config $Context.Config -Key 'installRoot'
        if (Test-ConfigValueIsDefault -Value $current -Default '%USERPROFILE%\winst') { return '[默认]' }
        return '[自定义]'
    }

    if ($Key -eq 'pkgDir') {
        if ($optionPkgDir) { return '[参数]' }
        if ($env:WINST_PKG_DIR -and $env:WINST_PKG_DIR.Trim()) { return '[环境变量]' }
        if ((Get-WinstState -Name WinstScriptDir)) {
            $scriptApps = Join-Path (Get-WinstState -Name WinstScriptDir) 'apps'
            if (Test-Path -LiteralPath $scriptApps -PathType Container) { return '[U盘]' }
        }
        $current = Get-ConfigValue -Config $Context.Config -Key 'pkgDir'
        if (Test-ConfigValueIsDefault -Value $current -Default (Join-Path $Context.DataRoot 'apps')) { return '[默认]' }
        return '[自定义]'
    }

    $defaults = Get-WinstConfigDefaults -DataRoot $Context.DataRoot
    $defaultValue = Get-ConfigValue -Config $defaults -Key $Key
    $currentValue = Get-ConfigValue -Config $Context.Config -Key $Key

    if (Test-ConfigValueIsDefault -Value $currentValue -Default $defaultValue) { return '[默认]' }
    return '[自定义]'
}
