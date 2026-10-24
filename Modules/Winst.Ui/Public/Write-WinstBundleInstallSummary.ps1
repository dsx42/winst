#Requires -Version 5.1

function Write-WinstBundleInstallSummary {
    <#
    .SYNOPSIS
        打印安装清单批量执行后的汇总行（菜单与 CLI 共用）。
    #>
    param([hashtable]$Stats)

    $parts = @(('已安装 {0}' -f [int]$Stats['OkCount']))
    if ([int]$Stats['DownloadOkCount'] -gt 0) { $parts += ('其中已下载软件包 {0}' -f [int]$Stats['DownloadOkCount']) }
    if ([int]$Stats['SkipCount'] -gt 0) { $parts += ('跳过 {0}' -f [int]$Stats['SkipCount']) }
    if ([int]$Stats['MissingCount'] -gt 0) { $parts += ('软件源里没有 {0}' -f [int]$Stats['MissingCount']) }
    if ([int]$Stats['PinSkipped'] -gt 0) { $parts += ('版本不符跳过 {0}' -f [int]$Stats['PinSkipped']) }
    if ([int]$Stats['CancelCount'] -gt 0) { $parts += ('取消 {0}' -f [int]$Stats['CancelCount']) }
    if ([int]$Stats['FailCount'] -gt 0) { $parts += ('失败 {0}' -f [int]$Stats['FailCount']) }
    $failCount = [int]$Stats['FailCount']
    Write-Host ('  汇总: {0}' -f ($parts -join ' / ')) -ForegroundColor $(if ($failCount -gt 0) { 'Yellow' } else { 'Gray' })
}
