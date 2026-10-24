#Requires -Version 5.1

function New-WinstContext {
    <#
    .SYNOPSIS
        汇总运行上下文：数据根目录、配置、安装根目录、包目录及其来源标记。
    #>
    param(
        [hashtable]$Options
    )

    $dataRoot = Get-DataRoot
    $config = Get-WinstConfig -DataRoot $dataRoot
    $installRoot = Resolve-InstallRoot -DataRoot $dataRoot -Options $Options -Config $config
    $pkg = Resolve-PkgDir -DataRoot $dataRoot -Options $Options -Config $config

    $context = @{
        DataRoot         = $dataRoot
        Config           = $config
        InstallRoot      = $installRoot
        PkgDir           = $pkg.Path
        InstallRootLabel = ''
        PkgDirLabel      = ''
    }
    $context.InstallRootLabel = Get-ConfigTag -Context $context -Key 'installRoot'
    $context.PkgDirLabel = Get-ConfigTag -Context $context -Key 'pkgDir'

    return $context
}
