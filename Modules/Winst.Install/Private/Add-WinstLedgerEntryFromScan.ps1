#Requires -Version 5.1

function Add-WinstLedgerEntryFromScan {
    <#
    .SYNOPSIS
        为扫描发现的软件新建记录；扫描不能证明系统项由 winst 写入，不认领 applied*。
    #>
    param([hashtable]$Context, $State, [string]$Id, $Info, $Plan, [string]$Now, [hashtable]$Counters)

    $app = $null
    if ($Plan.Contains($Id)) { $app = $Plan[$Id] }
    $appliedEnv = @()
    $appliedPath = @()
    $appliedShortcuts = @()

    Set-WinstInstalledApp -State $State -Id $Id -Entry ([ordered]@{
        version          = [string]$Info['Version']
        type             = [string]$Info['Type']
        installDir       = [string]$Info['InstallDir']
        installedAt      = $Now
        updatedAt        = $Now
        manifestOrigin   = [string]$Info['Source']
        managed          = [string]$Info['Managed']
        appliedEnv       = $appliedEnv
        appliedPath      = $appliedPath
        appliedShortcuts = $appliedShortcuts
        # 本机并存的低版本：供「已装软件」提醒用户清理旧版本
        oldVersions      = @(Merge-WinstScanOldVersions -Info $Info -CurrentVersion ([string]$Info['Version']))
        # 卸载操作快照：repair 重建时按当前生效清单写入
        uninstall        = $(if ($app -and [string]$Info['Managed'] -eq 'winst') { Get-WinstUninstallSnapshotFromPlan -Plan $app } else { ConvertTo-WinstUninstallSnapshot -Block $null })
    })
    $Counters.Added++
    $Counters.Changed = $true
    $newDir = [string]$Info['InstallDir']
    if (-not $newDir) { $newDir = '（未记录）' }
    if ([bool]$Info['DirOnly']) {
        $Counters.DirOnlyAdded++
        Write-Host ('    [+] 登记 {0}  版本 {1}  目录 {2}  [清单里没有对应软件，仅按目录登记]' -f $Id, [string]$Info['Version'], $newDir) -ForegroundColor Gray
    } else {
        Write-Host ('    [+] 登记 {0}  版本 {1}  目录 {2}  [{3}]' -f $Id, [string]$Info['Version'], $newDir, [string]$Info['Managed']) -ForegroundColor Gray
        $oldText = Format-WinstOldVersionText -OldVersions @(Get-EntryArray -Entry $Info -Key 'OldVersions')
        if ($oldText) {
            Write-Host ('        本机还并存旧版本 {0}（可在「已装软件」详情里清理）' -f $oldText) -ForegroundColor DarkGray
        }
    }
}
