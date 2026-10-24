#Requires -Version 5.1

function Get-WinstInstallFinalVersion {
    <#
    .SYNOPSIS
        ⑥ 版本检测：检测命中用检测值；未命中回落为本次安装的目标版本，再回落到台账里原本记着的版本。
    .DESCRIPTION
        检测未命中 → 回落为「本次安装的版本」（软件源里的版本）；软件源也没给版本号时**保留记录里原本
        记着的版本**，不把台账里的版本号抹成空。
    .OUTPUTS
        [string]
    #>
    param([hashtable]$Context, $Plan, [string]$InstallDir, [string]$Version, $Ledger, [switch]$Quiet)

    $finalVersion = $Version
    $detectResult = Get-WinstDetectedVersion -Context $Context -Plan $Plan -InstallDir $InstallDir
    if ($detectResult.Ok -and $detectResult.Version) {
        $finalVersion = [string]$detectResult.Version
        # 检测命令的输出只用来取版本号，绝不往 winst 界面上打；这里只在 --verbose 下给一行结论 + 取值途径
        if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            $verboseLine = ('  [verbose] 版本检测命中: {0}' -f $finalVersion)
            if ($detectResult.Detail) { $verboseLine += ('（{0}）' -f [string]$detectResult.Detail) }
            Write-Host $verboseLine -ForegroundColor DarkGray
        }
        return $finalVersion
    }

    # 检测本身没跑成（命令超时 / 缺 java / 起不来）时给一行提示：版本号回落为本次安装的目标版本，
    # 安装本身照常完成
    if ($detectResult.Note -and -not $Quiet) {
        Write-Host ('    提示: 版本检测未完成 —— {0}' -f [string]$detectResult.Note) -ForegroundColor DarkYellow
    }
    if (-not $finalVersion -and $Ledger) {
        $ledgerVersion = Get-EntryString -Entry $Ledger -Key 'version'
        if ($ledgerVersion -and $ledgerVersion -ine 'unknown') { $finalVersion = $ledgerVersion }
    }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        if ($finalVersion -and $finalVersion -eq $Version) {
            Write-Host ('  [verbose] 版本检测未命中，记录本次安装的目标版本 {0}' -f $Version) -ForegroundColor DarkGray
        } elseif ($finalVersion) {
            Write-Host ('  [verbose] 版本检测未命中、软件源里也没有版本号，保留记录里的版本 {0}' -f $finalVersion) -ForegroundColor DarkGray
        } else {
            Write-Host '  [verbose] 版本检测未命中，且这次拿不到任何可用的版本号' -ForegroundColor DarkGray
        }
    }
    return $finalVersion
}
