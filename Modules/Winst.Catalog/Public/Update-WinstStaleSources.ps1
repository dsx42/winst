#Requires -Version 5.1

function Update-WinstStaleSources {
    <#
    .SYNOPSIS
        刷新软件源：默认按「源有效期 + 单软件版本信息有效期」按需刷新。
    .DESCRIPTION
        `--offline` 跳过（回退缓存）；`--dry-run` 也跳过（刷新会写盘，预览模式不写盘）。
        **按需刷新（默认）**：调用方用 `-OnlyIds` 传入「需要展示的软件 id」（已装软件页传安装记录 id、
        搜索页传命中 id、安装 / 下载传目标 id）；未传时以解析锁缓存里的全部软件为候选。
        只有候选中「没有解析记录 / per-app resolvedAt 缺失或超过 `manifestTTLHours`」的软件才逐条解析
        （等待期间提示「正在按需解析 …」），其余一律沿用既有解析锁缓存；候选全部有效时整源跳过（零网络、零解析）。
        未传 `-OnlyIds` 且源本体超过 `manifestTTLHours` 有效期时仍会整源刷新（重新下载清单并全量解析，
        旧语义，保证新增软件能被发现）；本地清单刷新零网络请求（只是重新读文件）。
        **`-Force` 忽略源有效期、强制下载清单本体**：
        传 `-OnlyIds` 时只解析这些软件（检查更新只解析已装软件的最新版本），不传则全量解析（手动刷新同款）。
        失败仍按调用方的提示处理（回退缓存，不阻断后续操作）。
    .OUTPUTS
        @{ Refreshed; Failed; Skipped; Errors }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet,
        [switch]$Force,
        [string[]]$OnlyIds = @()
    )

    $result = @{ Refreshed = 0; Failed = 0; Skipped = $false; Errors = @() }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) { $result.Skipped = $true; return $result }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) { $result.Skipped = $true; return $result }

    $ttl = 24
    try { $ttl = [int](Get-ConfigValue -Config $Context.Config -Key 'manifestTTLHours') } catch { $ttl = 24 }

    # 先挑出要动作的源与每个源要解析的软件：
    #   -Force           → 全部源；解析集合 = OnlyIds（不传 = 全量，旧语义）
    #   非 Force（按需）  → 只动「展示集合里有版本信息需要更新」的源；解析集合 = 其中过期的那些；
    #                      未传 OnlyIds 且源本体超期 → 整源刷新（全量解析，旧语义）
    $now = Get-Date
    $hasOnlyIds = (@($OnlyIds).Count -gt 0)
    $staleSources = @()
    $resolveIdsBySource = @{}
    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = [string]$source['name']
        $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $name

        if ($Force) {
            $staleSources += $source
            if ($hasOnlyIds) { $resolveIdsBySource[$name] = @($OnlyIds) }
            continue
        }

        # 非 Force：per-app 有效期判断只依赖解析锁缓存（meta.Apps 的 per-app resolvedAt），
        # 不读清单缓存文件——展示集合全部有效时零额外开销
        $resolvedAtById = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal)
        if ($meta -and $meta.HasApps) {
            foreach ($oldApp in @($meta.Apps)) {
                $oldId = Get-EntryString -Entry $oldApp -Key 'id'
                if ($oldId -and -not $resolvedAtById.ContainsKey($oldId)) {
                    $resolvedAtById[$oldId] = Get-EntryString -Entry $oldApp -Key 'resolvedAt'
                }
            }
        }

        $manifestStale = $true
        if ($ttl -gt 0 -and $meta -and $meta.FetchedAt) {
            $stamp = [datetime]::MinValue
            if ([datetime]::TryParse([string]$meta.FetchedAt, [ref]$stamp)) {
                if (($now - $stamp).TotalHours -lt $ttl) { $manifestStale = $false }
            }
        }

        $needed = @()
        if ($hasOnlyIds) {
            # 只考虑缓存里确实存在的展示软件（新出现的条目由 -IncludeUnresolved 在刷新时补齐；
            # 不在本源缓存里的 id 视为不属于本源，由其他源处理，避免每个源都为未知 id 空转）。
            # 例外：本地清单的清单文件就在手边，读一下（纯本地 IO，零网络）就能确认 id 归属——
            # 在册的「从未解析」条目也纳入本次解析，解析锁首次写进 sidecar；
            # 否则 sidecar 缺失 / 被清理后，download <id> 这类单软件操作会误报「软件源里没有找到」
            foreach ($id in @($OnlyIds)) {
                if (-not $resolvedAtById.ContainsKey($id)) {
                    if ([bool]$source['isLocal'] -and (Test-WinstLocalManifestHasId -Context $Context -Id $id)) {
                        $needed += $id
                    }
                    continue
                }
                if (Test-WinstResolvedAtStale -ResolvedAt $resolvedAtById[$id] -Now $now -TtlHours $ttl) {
                    $needed += $id
                }
            }
            if ($needed.Count -eq 0) { continue }
            $staleSources += $source
            $resolveIdsBySource[$name] = $needed
        } else {
            foreach ($oldId in @($resolvedAtById.Keys)) {
                if (Test-WinstResolvedAtStale -ResolvedAt $resolvedAtById[$oldId] -Now $now -TtlHours $ttl) {
                    $needed += [string]$oldId
                }
            }
            if ($needed.Count -gt 0) {
                $staleSources += $source
                $resolveIdsBySource[$name] = $needed
            } elseif ($manifestStale) {
                # 版本信息都还新鲜，但清单本体超期：整源刷新（全量解析，旧语义），顺带发现新增软件
                $staleSources += $source
                $resolveIdsBySource[$name] = @()
            }
        }
    }
    if ($staleSources.Count -eq 0) { return $result }

    if (-not $Quiet) {
        if ($Force) {
            Write-Host '  正在刷新软件源 …' -ForegroundColor Gray
        } else {
            Write-Host ('  正在更新软件源（版本信息超过 {0} 小时的按需刷新）…' -f $ttl) -ForegroundColor Gray
        }
    }
    foreach ($source in $staleSources) {
        $name = [string]$source['name']
        $onlyIds = @()
        if ($resolveIdsBySource.ContainsKey($name)) { $onlyIds = @($resolveIdsBySource[$name]) }
        if (-not $Quiet) { Write-Host ('    刷新软件源 {0} …' -f $name) -ForegroundColor Gray }
        $r = Update-ManifestSource -Context $Context -Source $source -OnlyIds $onlyIds -IncludeUnresolved:(-not $hasOnlyIds -and $onlyIds.Count -gt 0)
        if ($r.Success) {
            $result.Refreshed++
        } else {
            $result.Failed++
            $result.Errors += ('{0}: {1}' -f $name, $r.Message)
        }
    }
    return $result
}
