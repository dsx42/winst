#Requires -Version 5.1

function Remove-WinstObsoletePackages {
    <#
    .SYNOPSIS
        自动清理旧包。
    #>
    param([hashtable]$Context, [string]$Id, $Plans, [bool]$DownloadedAny, [switch]$Offline)

    if (-not $DownloadedAny -or $Offline) { return }
    $keepNames = @()
    foreach ($filePlan in @($Plans)) { if ($filePlan['Name']) { $keepNames += [string]$filePlan['Name'] } }
    $prune = $true
    try { $prune = [bool](Get-ConfigValue -Config $Context.Config -Key 'pruneOldPackages') } catch { $prune = $true }
    if (-not $prune) { return }
    $removed = @(Remove-WinstOldPackages -Context $Context -Id $Id -KeepFiles $keepNames)
    if ($removed.Count -gt 0 -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 已清理旧安装包: {0}' -f ($removed -join '、')) -ForegroundColor DarkGray
    }
}
