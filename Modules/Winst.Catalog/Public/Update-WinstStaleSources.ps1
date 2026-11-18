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
        旧语义，保证新增软件能被发现）；本地清单正文只读文件，条目解析仍可能联网。
        **`-Force` 忽略源有效期、强制下载清单本体**：
        传 `-OnlyIds` 时只解析这些软件（检查更新只解析已装软件的最新版本），不传则全量解析（手动刷新同款）。
        再加 `-HonorEntryTtl`（只在 `-Force` 下生效，单独传入会被忽略）时只解析 `-OnlyIds` 里
        「per-app resolvedAt 超过 `manifestTTLHours`」的软件；
        一条都不过期就整源跳过（不下载清单本体、不写 sidecar）——共享 pkgDir（UNC）的「检查更新」用它
        避免每台机器每次都把同一批条目重新联网解析。本源没有解析锁（新换的共享目录、旧版本留下的 sidecar）
        时不做过滤，仍按 `-OnlyIds` 全解析，否则这些 id 会被当成「不属于本源」而永远不刷新。
        失败仍按调用方的提示处理（回退缓存，不阻断后续操作）。
    .OUTPUTS
        @{ Refreshed; Failed; Skipped; Errors }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet,
        [switch]$Force,
        [switch]$HonorEntryTtl,
        [string[]]$OnlyIds = @()
    )

    $result = @{ Refreshed = 0; Failed = 0; Skipped = $false; Errors = @(); Network = $false }
    $options = Get-WinstState -Name WinstOptions
    if ($options -and ($options.Offline -or $options.DryRun)) { $result.Skipped = $true; return $result }

    $persistUnavailable = Get-WinstState -Name WinstManifestPersistUnavailable

    $ttl = 24
    try { $ttl = [int](Get-ConfigValue -Config $Context.Config -Key 'manifestTTLHours') } catch { $ttl = 24 }

    # 先挑出要动作的源与每个源要解析的软件：
    #   -Force           → 全部源；解析集合 = OnlyIds（不传 = 全量，旧语义）
    #   -Force + HonorEntryTtl → 解析集合 = OnlyIds 里过期的那些；一条都不过期就整源跳过
    #   非 Force（按需）  → 只动「展示集合里有版本信息需要更新」的源；解析集合 = 其中过期的那些；
    #                      未传 OnlyIds 且源本体超期 → 整源刷新（全量解析，旧语义）
    $now = Get-Date
    $hasOnlyIds = (@($OnlyIds).Count -gt 0)
    $staleSources = @()
    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = [string]$source['name']
        try {
            if ($persistUnavailable.ContainsKey((Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $name))) {
                $result.Failed++
                $result.Errors += ('{0}: 上次刷新已取到最新数据，但缓存写不进去（目标盘当前不可用，或缓存目录不允许写入）；本会话内不再重复刷新。' -f $name)
                continue
            }

            $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $name
            $ids = $OnlyIds
            if (-not $Force -or ($HonorEntryTtl -and $hasOnlyIds -and $meta -and $meta.HasApps)) {
                $resolvedAtById = New-WinstOrdinalDictionary
                if ($meta -and $meta.HasApps) {
                    foreach ($app in @($meta.Apps)) {
                        $id = Get-EntryString -Entry $app -Key 'id'
                        if ($id -and -not $resolvedAtById.Contains($id)) {
                            $resolvedAtById[$id] = Get-EntryString -Entry $app -Key 'resolvedAt'
                        }
                    }
                }
                $candidates = $OnlyIds
                if (-not $hasOnlyIds) { $candidates = $resolvedAtById.Keys }
                $lookup = @{}
                $ids = @(foreach ($id in $candidates) {
                    if ($resolvedAtById.Contains($id)) {
                        if (Test-WinstResolvedAtStale -ResolvedAt $resolvedAtById[$id] -Now $now -TtlHours $ttl) { $id }
                    } elseif (Test-WinstManifestSourceMayContainId -Context $Context -Source $source -Id $id -Lookup $lookup) {
                        $id
                    }
                })
                if ($ids.Count -eq 0) {
                    if ($hasOnlyIds) { continue }
                    # 候选均有效时，仅源本体过期才全量刷新以发现新增软件。
                    $stamp = [datetime]::MinValue
                    if ($ttl -gt 0 -and $meta -and [datetime]::TryParse([string]$meta.FetchedAt, [ref]$stamp) -and
                        ($now - $stamp).TotalHours -lt $ttl) { continue }
                }
            }
            $staleSources += @{ Source = $source; Ids = $ids }
        } catch {
            $result.Failed++
            $result.Errors += ('{0}: {1}' -f $name, $_.Exception.Message)
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
    foreach ($pending in $staleSources) {
        $source = $pending.Source
        $name = [string]$source['name']
        $ids = $pending.Ids
        if (-not $Quiet) { Write-Host ('    刷新软件源 {0} …' -f $name) -ForegroundColor Gray }
        $r = Update-ManifestSource -Context $Context -Source $source -Force:$Force -OnlyIds $ids -IncludeUnresolved:(-not $hasOnlyIds -and $ids.Count -gt 0)
        $result.Network = $result.Network -or [bool]$r.Network
        if ($r.Success) {
            $result.Refreshed++
        } else {
            $result.Failed++
            $result.Errors += ('{0}: {1}' -f $name, $r.Message)
        }
    }
    return $result
}
