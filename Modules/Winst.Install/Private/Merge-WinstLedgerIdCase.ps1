#Requires -Version 5.1

function Merge-WinstLedgerIdCase {
    <#
    .SYNOPSIS
        台账里存在「id 仅大小写不同、且指向同一安装目录」的重复记录时，按清单 id 合并该记录。
    .OUTPUTS
        [bool] 是否发生了合并
    #>
    param($State, [string]$Id, $Info, [hashtable]$Counters)

    # （state.json 不允许同时存在仅大小写不同的键：PS 5.1 / 7 的 ConvertFrom-Json 都会拒绝这种 JSON）
    $duplicateId = ''
    foreach ($key in @($State['Installed'].Keys)) {
        $keyText = [string]$key
        if ($keyText -cne $Id -and $keyText -ieq $Id) {
            $duplicateEntry = $State['Installed'][$keyText]
            $duplicateDir = Get-EntryString -Entry $duplicateEntry -Key 'installDir'
            if ($duplicateDir -and ([string]$duplicateDir).TrimEnd('\') -ieq ([string]$Info['InstallDir']).TrimEnd('\')) { $duplicateId = $keyText; break }
        }
    }
    if (-not $duplicateId) { return $false }

    $duplicateEntry = $State['Installed'][$duplicateId]
    $duplicateVersion = Get-EntryString -Entry $duplicateEntry -Key 'version'
    if (-not $duplicateVersion) { $duplicateVersion = 'unknown' }
    $detectedVersion = [string]$Info['Version']
    if ($detectedVersion -and $detectedVersion -ne 'unknown' -and $detectedVersion -ne $duplicateVersion) {
        $duplicateEntry['version'] = $detectedVersion
        $Counters.Updated++
    }
    $null = Remove-WinstInstalledApp -State $State -Id $duplicateId
    Set-WinstInstalledApp -State $State -Id $Id -Entry $duplicateEntry
    $Counters.Changed = $true
    Write-Host ('    [~] 记录改名 {0} → {1}（id 按清单更正）  目录 {2}' -f $duplicateId, $Id, (Get-EntryString -Entry $duplicateEntry -Key 'installDir')) -ForegroundColor Gray
    return $true
}
