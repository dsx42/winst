#Requires -Version 5.1

function Show-WinstInstallTargetConfirm {
    <#
    .SYNOPSIS
        确认菜单（只问「装 / 不装」；强制重装由跳过后的二次询问提供）。
    .OUTPUTS
        @{ Proceed }
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
    Write-Host '  回车 / 其它任意输入 = 取消' -ForegroundColor DarkGray
    $text = Read-WinstAnswerText -Prompt '  请输入（y = 继续）'

    if ($text -notmatch '^(?i)y(es)?$') {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return @{ Proceed = $false }
    }
    return @{ Proceed = $true }
}
