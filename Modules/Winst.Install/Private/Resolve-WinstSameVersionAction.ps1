#Requires -Version 5.1

function Resolve-WinstSameVersionAction {
    <#
    .SYNOPSIS
        同版本时统一决定「仅配套文件更新」或直接跳过安装。
    #>
    param(
        $Install,
        [string]$InstallDir,
        [string]$DisplayName,
        [string]$Detected,
        [int]$CompanionDownloadCount,
        [bool]$HasCompanionUpdate,
        $Ledger,
        $Result,
        [switch]$DryRun,
        [switch]$Quiet
    )

    $narrowDirOk = $true
    if ((Get-EntryString -Entry $Install -Key 'method') -ne 'installer' -and
        (-not $InstallDir -or -not (Test-Path -LiteralPath $InstallDir -PathType Container))) {
        $narrowDirOk = $false
    }
    if ($HasCompanionUpdate -and $Ledger -and -not $narrowDirOk -and -not $Quiet) {
        Write-Host ('    提示: 安装目录不存在（{0}），本次不做「仅配套文件更新」；如需恢复请重新安装。' -f $InstallDir) -ForegroundColor DarkYellow
    }
    if ($HasCompanionUpdate -and $Ledger -and $narrowDirOk) {
        $Result.Version = $Detected
        if (-not $Quiet) {
            if ($DryRun) {
                Write-Host ('  {0} {1}：主包无变化，将只更新 {2} 个附加文件（预览，不重装）' -f $DisplayName, $Detected, $CompanionDownloadCount) -ForegroundColor DarkYellow
            } else {
                Write-Host ('  {0} {1}：主包无变化，只更新 {2} 个附加文件（不重装）' -f $DisplayName, $Detected, $CompanionDownloadCount) -ForegroundColor Gray
            }
        }
        return @{ Return = $false; Result = $null; Defer = $false; CompanionOnly = $true; Detected = $Detected }
    }
    return (Complete-WinstInstallSkip -Result $Result -Version $Detected `
        -Message ('{0} 已经是 {1}，无需重复安装' -f $DisplayName, $Detected))
}
