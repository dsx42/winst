#Requires -Version 5.1

function Resolve-WinstDeclaredKeywordMatches {
    <#
    .SYNOPSIS
        搜索零命中时，按关键字在清单正文里找软件，命中就解析这些条目（不与解析锁做差集）。
    .DESCRIPTION
        - 逐个软件源读清单正文（本地清单文件 / 远程正文缓存，不联网），用与搜索相同的规则匹配
          id / name / description 的子串，不区分大小写（整串优先，整串没命中再按空格 / 逗号 / 顿号拆词）；
        - 正文里有匹配就调用 Update-ManifestSource -OnlyIds 解析这些 id 并写回解析锁——
          正文里有就解析，不判断它是否已经在锁里；
        - 正文里找不到就是没有：不猜地址、不做额外探测；
        - 正文缓存不存在的源（从未刷新过）无从核对，留给解析锁为空时的整源刷新；
        - `--offline` / `--dry-run` 跳过（不联网 / 不写盘）。
    .OUTPUTS
        @{ Refreshed; Failed; Skipped; Errors }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Keyword,
        [switch]$Quiet
    )

    $result = @{ Refreshed = 0; Failed = 0; Skipped = $false; Errors = @() }
    # 关键字为空时每条都会被当成命中（IndexOf('') = 0），等于给每个源做一次全量解析：直接不做事
    if (-not ([string]$Keyword).Trim()) { return $result }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) { $result.Skipped = $true; return $result }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) { $result.Skipped = $true; return $result }

    $persistUnavailable = Get-WinstState -Name WinstManifestPersistUnavailable
    if ($null -eq $persistUnavailable) { $persistUnavailable = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal) }

    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = Get-EntryString -Entry $Source -Key 'name'
        if (-not $name) { continue }
        # 本进程内已确认「解析成功但写不进盘」的源不再重复尝试（与 Update-WinstStaleSources 同一口径）
        if ($persistUnavailable.ContainsKey($name)) { continue }

        $declared = Get-WinstDeclaredManifestEntries -Context $Context -Source $Source
        if ($declared.Error) {
            $result.Errors += [string]$declared.Error
            continue
        }
        $entries = @($declared.Entries)
        if ($entries.Count -eq 0) { continue }

        # 与 Get-WinstSearchCatalog 同一匹配口径：id / name / description 的子串，不区分大小写
        $match = {
            param([string]$Text)
            $found = @()
            foreach ($entry in $entries) {
                $id = Get-EntryString -Entry $entry -Key 'id'
                if (-not $id) { continue }
                $hit = $id.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0
                if (-not $hit) {
                    $displayName = Get-EntryString -Entry $entry -Key 'name'
                    if ($displayName) { $hit = $displayName.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
                }
                if (-not $hit) {
                    $description = Get-EntryString -Entry $entry -Key 'description'
                    if ($description) { $hit = $description.IndexOf($Text, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
                }
                # 统一成「带 Id 的行」：Merge-WinstKeywordSearch 按 $item['Id'] 去重，
                # 而 PS 5.1 不能索引 PSCustomObject（StrictMode 2 + EAP=Stop 下会直接终止搜索）
                if ($hit) { $found += [ordered]@{ Id = $id } }
            }
            return $found
        }
        # 整串优先 / 拆词合并 / 按 id 去重与软件源搜索共用同一套规则
        $matched = Merge-WinstKeywordSearch -Keyword $Keyword -Match $match
        $ids = @()
        foreach ($entry in @($matched.Items)) {
            $id = Get-EntryString -Entry $entry -Key 'id'
            if ($id -and $ids -notcontains $id) { $ids += $id }
        }
        if ($ids.Count -eq 0) { continue }

        if (-not $Quiet) {
            Write-Host ('  软件源 {0} 的清单里有 {1} 个匹配，正在解析 …' -f $name, $ids.Count) -ForegroundColor Gray
        }
        $r = Update-ManifestSource -Context $Context -Source $Source -OnlyIds $ids
        if (-not $r.Success) {
            $result.Failed++
            $result.Errors += ('{0}: {1}' -f $name, [string]$r.Message)
            if ([bool]$r.PersistUnavailable) { $persistUnavailable[$name] = $true }
            continue
        }
        # 正文缓存可能与当前 url 的清单不一致：命中的 id 在新清单里已不存在时解析数为 0，
        # 既没有成果、也不该触发调用方重搜
        if ([int]$r.Resolved -gt 0) { $result.Refreshed++ }
    }
    return $result
}
