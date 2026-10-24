#Requires -Version 5.1

function Try-Apply-WinstCommonCliFlag {
    <#
    .SYNOPSIS
        识别 install / update / uninstall / clean / list / manifest 等子命令共用的 CLI 开关，并写入 $script:WinstOptions。
    .OUTPUTS
        [bool] 是否为已识别的通用开关（调用方应 continue 跳过该 token）。
    #>
    param(
        [string]$Text,
        [ref]$Yes,
        [ref]$Offline
    )

    if (-not $Text) { return $false }

    if ($Text -eq '--offline') {
        if ($Offline) { $Offline.Value = $true }
        if ((Get-WinstState -Name WinstOptions)) { (Get-WinstState -Name WinstOptions).Offline = $true }
        return $true
    }
    if ($Text -eq '--dry-run') {
        if ((Get-WinstState -Name WinstOptions)) { (Get-WinstState -Name WinstOptions).DryRun = $true }
        return $true
    }
    if ($Text -eq '--verbose') {
        if ((Get-WinstState -Name WinstOptions)) { (Get-WinstState -Name WinstOptions).Verbose = $true }
        return $true
    }
    if ($Text -eq '--yes' -or $Text -eq '-y') {
        if ($Yes) { $Yes.Value = $true }
        if ((Get-WinstState -Name WinstOptions)) { (Get-WinstState -Name WinstOptions).Yes = $true }
        return $true
    }
    return $false
}
