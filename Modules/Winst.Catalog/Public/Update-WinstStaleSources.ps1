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

    $result = @{ Refreshed = 0; Failed = 0; Skipped = $false; Errors = @() }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) { $result.Skipped = $true; return $result }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) { $result.Skipped = $true; return $result }

    $persistUnavailable = Get-WinstState -Name WinstManifestPersistUnavailable
    if ($null -eq $persistUnavailable) { $persistUnavailable = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal) }
    $persistNoted = @()

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
    $resolveIdsBySource = @{}
    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = [string]$source['name']
        $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $name

        # 本进程内已经确认「解析成功但写不进盘」的源：不要再来一遍。
        # 有效期与解析锁都靠落盘文件判断，写不进去就永远是过期状态，
        # 不拦的话每次列表 / 检查 / 安装都会重跑同样的网络请求与解析。
        if ($persistUnavailable.ContainsKey((Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $name))) {
            if ($persistNoted -notcontains $name) {
                $persistNoted += $name
                $result.Errors += ('{0}: 上次刷新已取到最新数据，但缓存写不进去（目标盘当前不可用，或缓存目录不允许写入）；本会话内不再重复刷新。' -f $name)
            }
            continue
        }

        # per-app 解析时间（判断单条版本信息是否过期）：只依赖解析锁缓存（meta.Apps 的 per-app resolvedAt），
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

        if ($Force) {
            $ids = @($OnlyIds)
            # 没有解析锁（新换的共享目录、旧版本留下的 sidecar）时不做条目过滤：
            # 按「本源没有任何条目记录」直接全解析，否则这些 id 会被当成「不属于本源」而永远不刷新
            if ($HonorEntryTtl -and $hasOnlyIds -and $meta -and $meta.HasApps) {
                # 共享 pkgDir（UNC）下的「检查更新」：条目还在有效期内就沿用解析锁——
                # 一台机器刷新过，其它机器在 manifestTTLHours 内不必把同一批条目重新联网解析一遍。
                # 归属判断与按需刷新同一口径：解析锁缺失的 id 要按清单正文确认；正文不可用或过期则刷新确认
                $ids = @()
                foreach ($id in @($OnlyIds)) {
                    if (-not $resolvedAtById.ContainsKey($id)) {
                        if (Test-WinstManifestSourceMayContainId -Context $Context -Source $source -Id $id) { $ids += $id }
                        continue
                    }
                    if (Test-WinstResolvedAtStale -ResolvedAt $resolvedAtById[$id] -Now $now -TtlHours $ttl) { $ids += $id }
                }
                # 一条都没过期：整个源跳过（不重下清单本体、不解析、不写 sidecar）
                if ($ids.Count -eq 0) { continue }
            }
            $staleSources += $source
            if ($ids.Count -gt 0) { $resolveIdsBySource[$name] = $ids }
            continue
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
            # 解析锁可能是部分结果，缺失不能证明软件不属于本源；检查正文或刷新确认。
            foreach ($id in @($OnlyIds)) {
                if (-not $resolvedAtById.ContainsKey($id)) {
                    if (Test-WinstManifestSourceMayContainId -Context $Context -Source $source -Id $id) {
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
            # 解析成功、只是写不进盘：记下来，本进程内不再为同一个源重复刷新
            if ([bool]$r.PersistUnavailable) { $persistUnavailable[(Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $name)] = $true }
        }
    }
    return $result
}
