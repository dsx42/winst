#Requires -Version 5.1

function New-WinstContext {
    <#
    .SYNOPSIS
        汇总运行上下文：数据根目录、配置、安装根目录、包目录及其来源标记。
    #>
    param(
        [hashtable]$Options,
        [string]$DataRoot = (Get-DataRoot),
        [hashtable]$Config = (Get-WinstConfig -DataRoot $DataRoot)
    )

    $installSource = ''
    $installRoot = Resolve-InstallRoot -DataRoot $DataRoot -Options $Options -Config $Config -Source ([ref]$installSource)
    $pkg = Resolve-PkgDir -DataRoot $DataRoot -Options $Options -Config $Config

    $context = @{
        DataRoot          = $DataRoot
        Config            = $Config
        InstallRoot       = $installRoot
        PkgDir            = $pkg.Path
        InstallRootSource = $installSource
        PkgDirSource      = $pkg.Source
    }
    $context.InstallRootLabel = Get-ConfigTag -Context $context -Key 'installRoot'
    $context.PkgDirLabel = Get-ConfigTag -Context $context -Key 'pkgDir'

    return $context
}
