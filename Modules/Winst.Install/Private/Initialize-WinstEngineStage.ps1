#Requires -Version 5.1

function Initialize-WinstEngineStage {
    <#
    .SYNOPSIS
        在暂存目录完成引擎复制改名并校验主程序，失败时禁止替换旧树。
    #>
    param([string]$Id, $Plan, [string]$SourceDir)

    $copy = Invoke-WinstPostInstallCopy -Plan $Plan -InstallDir $SourceDir
    if (-not $copy.Ok) { throw ([string]$copy.Error) }
    $mainExe = Get-WinstEngineMainExe -Id $Id
    if (-not $mainExe) { return }
    $mainPath = Resolve-WinstSafeChildPath -Root $SourceDir -Child $mainExe -Label '引擎主程序'
    if (-not $mainPath.Ok) { throw ([string]$mainPath.Error) }
    if (-not (Test-Path -LiteralPath $mainPath.Path -PathType Leaf -ErrorAction Stop)) {
        throw ('引擎包中没有找到 {0}，原安装目录保持不变' -f $mainExe)
    }
}
