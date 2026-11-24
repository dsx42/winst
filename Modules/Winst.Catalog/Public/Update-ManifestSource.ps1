#Requires -Version 5.1

function Update-ManifestSource {
    <#
    .SYNOPSIS
        刷新单个软件源：取得清单 → 解析各软件最新版本与实际内容（软件清单）→ 写入 sidecar 元数据。
    .DESCRIPTION
        -OnlyIds：按需解析，只逐条解析命中的软件，未命中条目沿用 sidecar 既有
        解析锁缓存（版本与 per-app resolvedAt 原样保留）；清单中已移除的条目仍自然清退。
        本地清单（local）：直接读脚本同目录的清单文件，不下载、不改写清单正文；条目解析与地址探测仍可能联网；
        远程来源：固定 URL 直接重新下载；含 {version} 的先 GET 指示地址取最新版本，高于缓存版本（或 -Force）
        才下载；缓存清单已是最新时不重复下载，但仍重新解析（软件版本可能已前移）。
        **失败不覆盖成功结果**：本次解析失败的条目若上次成功过，则保留上次结果（备注写明本次失败原因），
        清单中已移除的条目从软件清单中清退；每次刷新都改写 meta.json 的更新时间。
        取得清单见 Get-WinstManifestPayload；解析见 Invoke-WinstManifestResolve；
        失败保留 / 按需合并见 Merge-WinstFailedAppResults / Merge-WinstOnDemandApps。
    .OUTPUTS
        @{ Success; Version; Message; Network; Apps; Resolved; ResolveFailed; Total }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source,
        [switch]$Force,
        [string[]]$OnlyIds = @(),
        # 仅 -OnlyIds 模式生效：清单里「从未解析过」（缓存里没有）的条目一并解析——
        # 按需刷新也能逐步补齐上游新增的软件；检查更新等严格按 OnlyIds 的调用方不传它
        [switch]$IncludeUnresolved
    )

    $name = Get-EntryString -Entry $Source -Key 'name'
    $url = Get-EntryString -Entry $Source -Key 'url'
    $isLocal = Get-EntryBool -Entry $Source -Key 'isLocal'

    $save = $null
    try {
        $result = @{
            Success = $false; Version = ''; Message = ''; Network = $false
            Apps = @(); Resolved = 0; ResolveFailed = 0; Total = 0
        }

        if (-not $name) { $result.Message = '软件源名称缺失'; return $result }
        if (-not $isLocal -and -not $url) { $result.Message = '软件源地址为空'; return $result }

        $cachePath = Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $name
        $hasCache = $false
        if ($cachePath) { $hasCache = Test-Path -LiteralPath $cachePath -PathType Leaf }

        $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $name
        $cachedVersion = ''
        if ($meta -and $meta.Version) { $cachedVersion = [string]$meta.Version }

        # 清单的「取得时刻」：在真正取值之前捕获，写进 meta.json 的 fetchedAt
        $fetchedAt = (Get-Date).ToString('s')

        # —— 取清单（本地 / 远程，含 {version} 指示地址与缓存复用） ——
        $payload = Get-WinstManifestPayload -Context $Context -Source $Source -Url $url -IsLocal:$isLocal `
            -CachePath $cachePath -HasCache:$hasCache -CachedVersion $cachedVersion -Force:$Force
        if (-not $payload.Ok) {
            $result.Message = [string]$payload.Message
            $result.Network = [bool]$payload.Network
            return $result
        }
        $entries = @($payload.Entries)
        $content = [string]$payload.Content
        $targetUrl = [string]$payload.TargetUrl
        $manifestVersion = [string]$payload.ManifestVersion
        $reusedFromCache = [bool]$payload.ReusedFromCache
        $writeCache = [bool]$payload.WriteCache

        # —— 按需解析的 id 集合（含「从未解析过」的补齐） ——
        $onlySet = Get-WinstResolveFilter -Entries $entries -OnlyIds $OnlyIds -Meta $meta -IncludeUnresolved:$IncludeUnresolved

        # —— 解析：逐条目解析最新版本与实际内容（失败隔离） ——
        $resolve = Invoke-WinstManifestResolve -Context $Context -Name $name -Entries $entries -OnlySet $onlySet
        $apps = @($resolve.Apps)
        $succeeded = [int]$resolve.Succeeded
        $failed = [int]$resolve.Failed

        # —— 失败不覆盖成功结果 ——
        $retain = Merge-WinstFailedAppResults -Apps $apps -Meta $meta -Failed $failed -Succeeded $succeeded
        $apps = @($retain.Apps)
        $succeeded = [int]$retain.Succeeded
        $failed = [int]$retain.Failed
        $retained = [int]$retain.Retained

        # —— 按需解析：未解析条目沿用 sidecar 缓存（清单中已移除的仍自然清退） ——
        $resolvedCount = 0
        if ($onlySet) {
            $merge = Merge-WinstOnDemandApps -Apps $apps -Entries $entries -Meta $meta
            $apps = @($merge.Apps)
            $resolvedCount = [int]$merge.Resolved
        }

        $retainNote = ''
        if ($retained -gt 0) {
            $retainNote = ('；本次检测失败 {0} 个，已保留上次成功结果' -f $retained)
        }

        $result.Apps = $apps
        $result.Resolved = $succeeded
        $result.ResolveFailed = $failed
        $result.Total = $entries.Count

        $options = Get-WinstState -Name WinstOptions
        if ($options -and $options.DryRun) {
            $result.Success = $true
            $result.Version = $manifestVersion
            $result.Message = ('（预览）共 {0} 个软件，可用 {1} / 有误 {2}{3}（未保存）' -f $entries.Count, $succeeded, $failed, $retainNote)
            return $result
        }

        $save = Save-WinstManifestRefresh -Context $Context -Name $name -CachePath $cachePath -Content $content `
            -WriteCache:$writeCache -TargetUrl $targetUrl -Version $manifestVersion -Apps $apps -FetchedAt $fetchedAt
        if ($save.Error) {
            $result.Message = [string]$save.Error
            return $result
        }

        $result.Success = $true
        $result.Version = $manifestVersion
        $result.Message = Format-WinstManifestRefreshMessage -IsLocal:$isLocal -ReusedFromCache:$reusedFromCache `
            -Version $manifestVersion -EntryCount $entries.Count -Succeeded $succeeded -Failed $failed `
            -ResolvedCount $resolvedCount -OnDemand:([bool]$onlySet) -RetainNote $retainNote
        return $result
    } finally {
        # 提前返回或抛错时也让下次依赖查询重建索引，持久化和会话回退由写入方失效。
        if ($null -eq $save) { Remove-WinstState -Name WinstDependencyIndex }
    }
}
