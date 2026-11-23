#Requires -Version 5.1

function Sync-WinstInstallerDecisionPath {
    <#
    .SYNOPSIS
        同版本 installer 跳过安装前，按系统探测结果修正或清除台账中的占位安装目录。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$Id,
        $Ledger,
        [switch]$Quiet, [string]$ProbedDir
    )

    $ledgerDir = Get-EntryString -Entry $Ledger -Key 'installDir'
    $clearPlaceholder = [bool](-not $ProbedDir -and $ledgerDir -ieq (Join-WinstPath $Context.InstallRoot $Id) -and
        -not (Get-WinstInstallerExpectedDir -Plan $Plan -InstallArgs '' -InstallDir $ledgerDir))
    if ($ProbedDir -and $ledgerDir -ine $ProbedDir) {
        $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot `
            -Id $Id -Entry $Ledger -Fields @{ installDir = $ProbedDir }
        if (-not $Quiet) { Write-Host ('    安装记录里的安装目录已按实际值修正: {0}' -f $ProbedDir) -ForegroundColor Gray }
    } elseif ($clearPlaceholder -and $ledgerDir) {
        $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot `
            -Id $Id -Entry $Ledger -Fields @{ installDir = '' }
        if (-not $Quiet) { Write-Host '    安装记录里的安装目录是占位路径（winst 未掌握实际位置），已清空；下次解析到实际位置时会自动补上。' -ForegroundColor DarkGray }
    }
}
