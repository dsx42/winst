#Requires -Version 5.1

function Update-WinstLedgerFromScan {
    <#
    .SYNOPSIS
        ⑤ 合并台账：补缺失 / 版本变化时更新 / 其余保持原值（计数器通过 Counters 哈希表回传）。
    #>
    param([hashtable]$Context, $State, $Found, $Plan, [string]$Now, [hashtable]$Counters, [switch]$Quiet)

    foreach ($id in @($Found.Keys)) {
        $info = $Found[$id]
        $existing = Get-WinstInstalledApp -State $State -Id $id
        if ($existing) {
            $existingVersion = Get-EntryString -Entry $existing -Key 'version'
            if (-not $existingVersion) { $existingVersion = 'unknown' }
            $recordDir = Get-EntryString -Entry $existing -Key 'installDir'
            if (-not $recordDir) { $recordDir = '（未记录）' }
            $detected = [string]$info['Version']

            if (-not $detected -or $detected -eq 'unknown') {
                # 本次没识别出版本：保持记录原样（未配置版本检测 / 检测未命中 / 清单里没有对应条目）
                $Counters.Kept++
                $detectMethod = 'none'
                if (-not [bool]$info['DirOnly'] -and $Plan.Contains($id)) {
                    $detectBlock = Get-EntryValue -Entry $Plan[$id] -Key 'detect' -Default $null
                    $detectMethod = (Get-EntryString -Entry $detectBlock -Key 'method').Trim().ToLowerInvariant()
                    if (-not $detectMethod) { $detectMethod = 'none' }
                }
                if (-not $Quiet) {
                    if ([bool]$info['DirOnly']) {
                        Write-Host ('    [=] 已登记 {0}  版本 {1}（软件源里没有这个软件，仅按目录登记）  目录 {2}' -f $id, $existingVersion, $recordDir) -ForegroundColor DarkGray
                    } elseif ($detectMethod -eq 'none') {
                        Write-Host ('    [=] 已登记 {0}  版本 {1}（未配置版本检测，保留原版本）  目录 {2}' -f $id, $existingVersion, $recordDir) -ForegroundColor DarkGray
                    } else {
                        Write-Host ('    [=] 已登记 {0}  版本 {1}（本次未识别出新版本，未改动记录）  目录 {2}' -f $id, $existingVersion, $recordDir) -ForegroundColor DarkGray
                    }
                }
                continue
            }

            if ($existingVersion -eq $detected) {
                $Counters.Kept++
                if (-not $Quiet) {
                    Write-Host ('    [=] 已登记 {0}  版本 {1}（与记录一致，未改动）  目录 {2}' -f $id, $existingVersion, $recordDir) -ForegroundColor DarkGray
                }
                continue
            }

            # 内容发生了变化：更新记录里的版本
            $existing['version'] = $detected
            $Counters.Changed = $true
            if ($existingVersion -eq 'unknown') {
                $Counters.Filled++
                Write-Host ('    [~] 补全版本 {0} → {1}  目录 {2}' -f $id, $detected, $recordDir) -ForegroundColor Gray
            } else {
                $Counters.Updated++
                Write-Host ('    [~] 更正版本 {0}：{1} → {2}  目录 {3}' -f $id, $existingVersion, $detected, $recordDir) -ForegroundColor Gray
            }
            continue
        }

        if (Merge-WinstLedgerIdCase -State $State -Id $id -Info $info -Counters $Counters) { continue }

        Add-WinstLedgerEntryFromScan -Context $Context -State $State -Id $id -Info $info -Plan $Plan -Now $Now -Counters $Counters
    }
}
