#Requires -Version 5.1

function Invoke-WinstBundlePackCli {
    <#
    .SYNOPSIS
        CLI `bundle pack <list> <dir> [--skip-missing]`：生成 U 盘离线套件（非交互）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$ListText = '',
        [string]$DirText = '',
        [switch]$SkipMissing
    )

    Write-Section 'winst bundle pack'

    if (-not $DirText) {
        Write-Host ''
        Write-Host '  用法: winst bundle pack <安装清单> <目标目录> [--skip-missing]' -ForegroundColor Yellow
        return 1
    }

    $target = Resolve-WinstListFileForCli -Context $Context -Text $ListText
    if (-not $target.Ok) { return 1 }

    $result = Invoke-WinstPack -Context $Context -ListPath ([string]$target.Path) -TargetDir $DirText `
        -SkipMissing:$SkipMissing -NonInteractive
    if ($result.Cancelled) { return 1 }
    if (-not $result.Ok) {
        if ($result.Error) { Write-Host ('  {0}' -f $result.Error) -ForegroundColor Red }
        return 1
    }
    return 0
}
