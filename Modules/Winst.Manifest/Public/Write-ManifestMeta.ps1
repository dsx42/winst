#Requires -Version 5.1

function Write-ManifestMeta {
    <#
    .SYNOPSIS
        内容变化时原子写入 sidecar 元数据：{ url, version, fetchedAt, resolvedAt, apps }（UTF-8 无 BOM）。
    .DESCRIPTION
        apps 为逐软件的解析锁：刷新时按各来源解析出
        最新版本，以及「下载 → 解压/安装 → 复制/移动 → 环境变量 → 安装后命令 → 版本检测 → 卸载」
        全流程的实际内容。未传入 Apps 时不写该字段。
        所有字段相同时不写盘、不失效汇总缓存；刷新时间变化仍需保存，以维持有效期判断。
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
    $written = Write-WinstJsonFileIfChanged -Path $path -InputObject $obj -Depth 12

    $sessionMeta = Get-WinstState -Name WinstManifestSessionMeta
    $hadSessionMeta = ($null -ne $sessionMeta -and $sessionMeta.ContainsKey($path))
    if ($hadSessionMeta) { $sessionMeta.Remove($path) }
    $unavailable = Get-WinstState -Name WinstManifestPersistUnavailable
    if ($null -ne $unavailable) { $unavailable.Remove($path) }

    # 磁盘记录变化或会话覆盖被移除时，软件清单汇总缓存必须重建。
    if ($written -or $hadSessionMeta) { Reset-WinstCatalogCache }
}
