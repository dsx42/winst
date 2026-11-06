#Requires -Version 5.1

function Show-WinstInstallTargetConfirm {
    <#
    .SYNOPSIS
        确认安装或刷新当前软件的来源信息；强制重装由跳过后的二次询问提供。
    .OUTPUTS
        @{ Proceed; Refresh }
    #>
    param($Row, [string]$ActionText, [string]$PlanVersion, [string]$InstalledVersion, [bool]$IsUpgrade,
        [bool]$CompanionOnlyPrompt, $CompanionInfo, [switch]$FilesOnly)

    Write-Host ''
    if ($CompanionOnlyPrompt) {
        Write-Host ('  y) 只更新 {0} 个附加文件（主包无变化，不会重装）' -f $CompanionInfo.ChangedCount) -ForegroundColor Green
    } elseif ($IsUpgrade) {
        if ($FilesOnly) {
            Write-Host ('  y) 更新到 {0}  ↑（仅更新文件；本机已安装 {1}）' -f $PlanVersion, $InstalledVersion) -ForegroundColor Green
        } else {
            Write-Host ('  y) 更新到 {0}  ↑（本机已安装 {1}）' -f $PlanVersion, $InstalledVersion) -ForegroundColor Green
        }
    } else {
        Write-Host ('  y) {0}「{1}」{2}' -f $ActionText, ([string]$Row['Name']), $(if ($FilesOnly) { '（仅更新文件）' } else { '' })) -ForegroundColor White
    }
    Write-Host '  s) 刷新这个软件条目的软件源' -ForegroundColor White
    Write-Host '  回车 / 其它任意输入 = 取消' -ForegroundColor DarkGray
    $text = Read-WinstAnswerText -Prompt '  请输入（y = 继续，s = 刷新软件源）'

    if ($text -ieq 's') { return @{ Proceed = $false; Refresh = $true } }
    if ($text -notmatch '^(?i)y(es)?$') {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return @{ Proceed = $false; Refresh = $false }
    }
    return @{ Proceed = $true; Refresh = $false }
}
