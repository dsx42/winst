#Requires -Version 5.1

function Update-WinstContext {
    <#
    .SYNOPSIS
        重读 config.json 并就地刷新上下文（横幅与菜单显示立即反映新配置）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    $config = Get-WinstConfig -DataRoot $Context.DataRoot
    $pkg = Resolve-PkgDir -DataRoot $Context.DataRoot -Options (Get-WinstState -Name WinstOptions) -Config $config

    $Context.Config = $config
    $Context.InstallRoot = Resolve-InstallRoot -DataRoot $Context.DataRoot -Options (Get-WinstState -Name WinstOptions) -Config $config
    $Context.PkgDir = $pkg.Path
    $Context.InstallRootLabel = Get-ConfigTag -Context $Context -Key 'installRoot'
    $Context.PkgDirLabel = Get-ConfigTag -Context $Context -Key 'pkgDir'
}
