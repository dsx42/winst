#Requires -Version 5.1

function Sync-WinstInstallerDecisionPath {
    <#
    .SYNOPSIS
        同版本 installer 跳过安装前，按系统探测结果修正或清除台账中的占位安装目录。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$InstallDir,
        [string]$Id,
        $Result,
        $Ledger,
        [switch]$Quiet
    )

    $probedDir = (Resolve-WinstActualInstallDir -Plan $Plan -AssumedDir $InstallDir).Dir
    if ($probedDir) { $Result.InstallDir = $probedDir } else { $Result.InstallDir = '' }
    $ledgerDir = Get-EntryString -Entry $Ledger -Key 'installDir'
    $newDir = $Result.InstallDir
    $clearPlaceholder = [bool](-not $newDir -and $ledgerDir -ieq (Join-Path $Context.InstallRoot $Id) -and
        -not (Get-WinstInstallerExpectedDir -Plan $Plan -InstallArgs '' -InstallDir $ledgerDir))
    if ($newDir -and $ledgerDir -ine $newDir) {
        $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot `
            -Id $Id -Entry $Ledger -Fields @{ installDir = $newDir }
        if (-not $Quiet) { Write-Host ('    安装记录里的安装目录已按实际值修正: {0}' -f $newDir) -ForegroundColor Gray }
    } elseif ($clearPlaceholder -and $ledgerDir) {
        $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot `
            -Id $Id -Entry $Ledger -Fields @{ installDir = '' }
        if (-not $Quiet) { Write-Host '    安装记录里的安装目录是占位路径（winst 未掌握实际位置），已清空；下次解析到实际位置时会自动补上。' -ForegroundColor DarkGray }
    }
}
