#Requires -Version 5.1

function Read-ManifestMeta {
    <#
    .SYNOPSIS
        读取 sidecar 元数据；文件缺失或损坏返回 $null（清单缓存文件本身保留作离线兜底）。
    .OUTPUTS
        @{ Url; Version; FetchedAt; ResolvedAt; Apps; HasApps } 或 $null
    .DESCRIPTION
        Apps 为逐软件的「解析锁」：刷新时按各来源解析出的
        最新版本与下载 / 安装 / 卸载全流程实际内容。无该字段时 HasApps 为 $false，视为无锁。
    #>
    param([string]$PkgDir, [string]$Name)

    $path = Get-ManifestMetaPath -PkgDir $PkgDir -Name $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }

    try {
        # 解析结果进程内缓存：按 id 查 / 按源查 / 刷新过程中会反复读同一份 meta.json，
        # 每次 Get-Content + ConvertFrom-Json 是主要开销（时间戳或长度变了才重解析）
        $read = Read-WinstJsonFileCached -Path $path
        if (-not $read.Ok) { return $null }
        $obj = $read.Value
        if ($null -eq $obj) { return $null }
        $url = ''
        $version = ''
        $fetchedAt = ''
        $resolvedAt = ''
        $apps = @()
        $hasApps = $false
        $p = $obj.PSObject.Properties['url'];        if ($p) { $url = ConvertTo-WinstTextValue -Value $p.Value }
        $p = $obj.PSObject.Properties['version'];    if ($p) { $version = ConvertTo-WinstTextValue -Value $p.Value }
        $p = $obj.PSObject.Properties['fetchedAt'];  if ($p) { $fetchedAt = ConvertTo-WinstTextValue -Value $p.Value }
        $p = $obj.PSObject.Properties['resolvedAt']; if ($p) { $resolvedAt = ConvertTo-WinstTextValue -Value $p.Value }
        $p = $obj.PSObject.Properties['apps']
        if ($p -and $null -ne $p.Value) {
            $apps = @($p.Value)
            $hasApps = $true
        }
        return @{
            Url        = $url
            Version    = $version
            FetchedAt  = $fetchedAt
            ResolvedAt = $resolvedAt
            Apps       = $apps
            HasApps    = $hasApps
        }
    } catch {
        return $null
    }
}
