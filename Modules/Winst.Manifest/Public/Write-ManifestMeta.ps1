#Requires -Version 5.1

function Write-ManifestMeta {
    <#
    .SYNOPSIS
        原子写入 sidecar 元数据：{ url, version, fetchedAt, resolvedAt, apps }（UTF-8 无 BOM）。
    .DESCRIPTION
        apps 为逐软件的解析锁：刷新时按各来源解析出
        最新版本，以及「下载 → 解压/安装 → 复制/移动 → 环境变量 → 安装后命令 → 版本检测 → 卸载」
        全流程的实际内容。未传入 Apps 时不写该字段。
    #>
    param(
        [string]$PkgDir,
        [string]$Name,
        [string]$Url,
        [string]$Version,
        [string]$FetchedAt,
        [string]$ResolvedAt = '',
        $Apps = $null
    )

    $path = Get-ManifestMetaPath -PkgDir $PkgDir -Name $Name
    $obj = [ordered]@{ url = $Url; version = $Version; fetchedAt = $FetchedAt }
    if ($ResolvedAt) { $obj['resolvedAt'] = $ResolvedAt }
    if ($null -ne $Apps) { $obj['apps'] = @($Apps) }
    Write-FileAtomic -Path $path -Content (ConvertTo-WinstJson -InputObject $obj -Depth 12)

    $sessionMeta = Get-WinstState -Name WinstManifestSessionMeta
    if ($null -ne $sessionMeta) { $sessionMeta.Remove($path) }
    $unavailable = Get-WinstState -Name WinstManifestPersistUnavailable
    if ($null -ne $unavailable) { $unavailable.Remove($path) }

    # 解析锁变化 → 软件清单汇总缓存（搜索 / 依赖索引）必须重建
    Reset-WinstCatalogCache
}
