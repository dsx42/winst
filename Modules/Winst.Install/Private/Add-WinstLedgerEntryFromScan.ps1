#Requires -Version 5.1

function Add-WinstLedgerEntryFromScan {
    <#
    .SYNOPSIS
        为扫描到但台账里没有的软件新建一条记录（含按当前清单推导 applied* 登记）。
    #>
    param([hashtable]$Context, $State, [string]$Id, $Info, $Plan, [string]$Now, [hashtable]$Counters)

    $app = $null
    if ($Plan.Contains($Id)) { $app = $Plan[$Id] }
    $appliedEnv = @()
    $appliedPath = @()
    $appliedShortcuts = @()
    if ($app -and [string]$Info['Managed'] -eq 'winst') {
        # 按当前生效清单声明推导登记值
        $scope = Get-WinstInstallScope -InstallDir ([string]$Info['InstallDir'])
        foreach ($pair in @(Get-EntryKeyValuePairs -Entry (Get-EntryValue -Entry $app -Key 'env' -Default $null))) {
            $name = [string]$pair['Key']
            if ($name) { $appliedEnv += [ordered]@{ name = $name; scope = $scope } }
        }
        foreach ($item in @(Get-EntryArray -Entry $app -Key 'addToPath')) {
            $text = [string]$item
            if (-not $text) { continue }
            if ($text -ieq 'true' -or $text -ieq '{installDir}') { $text = [string]$Info['InstallDir'] }
            else { $text = Expand-PlanPlaceholders -Value $text -InstallDir ([string]$Info['InstallDir']) -InstallRoot $Context.InstallRoot }
            if ($text) { $appliedPath += [ordered]@{ path = $text; scope = $scope } }
        }
        foreach ($link in @(Get-WinstShortcutPaths -Plan $app)) { $appliedShortcuts += $link }
    }

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
    }
}
