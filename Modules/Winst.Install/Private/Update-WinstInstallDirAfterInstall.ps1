#Requires -Version 5.1

function Update-WinstInstallDirAfterInstall {
    <#
    .SYNOPSIS
        安装后回读系统安装记录取实际安装目录（读不到时沿用台账路径，占位路径按读不到处理）。
    .OUTPUTS
        @{ Ok; Error; InstallDir }
    #>
    param([hashtable]$Context, $Plan, [string]$InstallDir, $Ledger, [string]$Id, [string]$InstallArgs, [switch]$Quiet)

    # 回读系统安装记录，取实际安装目录：安装器可能装在 installRoot 之外，不能用 installRoot\id 假设。
    # 部分安装器由子进程稍后写安装记录，一时读不到就短暂重试几次，别把刚装好的软件记成「没有目录」。
    $assumedDir = $InstallDir
    $actual = @{ Dir = ''; FromRegistry = $false }
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $actual = Resolve-WinstActualInstallDir -Plan $Plan -AssumedDir $assumedDir
        if ($actual.Dir -or $attempt -ge 3) { break }
        Start-Sleep -Milliseconds 1200
    }
    if ($actual.Dir) {
        if ($actual.Dir -ine $assumedDir -and -not $Quiet) {
            Write-Host ('    实际安装目录: {0}' -f $actual.Dir) -ForegroundColor Gray
        }
        return @{ Ok = $true; Error = ''; InstallDir = $actual.Dir }
    }

    # 探测不到时沿用安装记录里已有的路径，避免把原本正确的路径抹掉
    $keptDir = ''
    if ($Ledger) { $keptDir = Get-EntryString -Entry $Ledger -Key 'installDir' }
    # installer 的台账里可能只有 installRoot\id 占位路径（winst 并没有往那里装过）：
    # 沿用这种假路径只会让「已安装到 …」继续报错位置，按读不到处理；
    # .msi 例外——winst 给 msiexec 传的 TARGETDIR 就是 installRoot\id，那里是真实安装位置
    if ($keptDir -ieq (Join-WinstPath $Context.InstallRoot $Id) -and -not (Get-WinstInstallerExpectedDir -Plan $Plan -InstallArgs $InstallArgs -InstallDir $keptDir)) {
        $keptDir = ''
    }
    if ($keptDir) {
        if (-not $Quiet) { Write-Host ('    本次读不到实际安装目录，沿用安装记录里的路径: {0}' -f $keptDir) -ForegroundColor DarkGray }
        return @{ Ok = $true; Error = ''; InstallDir = $keptDir }
    }
    if (-not $Quiet) {
        Write-Host '    暂时读不到实际安装目录（安装命令里没指定路径，系统安装记录里也没有），安装记录里的路径留空；下次进入「已装软件」时会自动重新扫描并补上。' -ForegroundColor DarkGray
    }
    return @{ Ok = $true; Error = ''; InstallDir = '' }
}
