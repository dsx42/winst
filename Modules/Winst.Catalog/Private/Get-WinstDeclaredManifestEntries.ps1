#Requires -Version 5.1

function Get-WinstDeclaredManifestEntries {
    <#
    .SYNOPSIS
        读取某软件源「清单正文」里声明的条目：不联网、不解析版本、不读解析锁。
    .DESCRIPTION
        搜索只覆盖解析锁（sidecar 的 apps）：部分刷新后「清单里有、还没解析过」的软件不在锁里，
        按名称搜不到。这里提供另一个查询入口——直接看清单正文写了什么：
          本地清单：读磁盘上的清单文件（Read-LocalManifestBundle，纯本地 IO）；
          远程来源：读 <pkgDir>\manifests\remote\<源>.json 正文缓存（每次刷新一并写入）。
        正文缓存不存在（从未刷新过）时没有可核对的内容，返回空条目，由调用方决定后续动作。
    .OUTPUTS
        @{ Entries; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $result = @{ Entries = @(); Error = '' }
    $name = Get-EntryString -Entry $Source -Key 'name'
    if (-not $name) { return $result }

    if (Get-EntryBool -Entry $Source -Key 'isLocal') {
        $local = Read-LocalManifestBundle -Context $Context -Source $Source
        if ($local.Error) {
            $result.Error = ('{0}: {1}' -f $name, [string]$local.Error)
            return $result
        }
        $result.Entries = @($local.Entries)
        return $result
    }

    $path = Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $name
    if (-not $path) { return $result }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $result }

    $read = Read-WinstJsonFileCached -Path $path
    if (-not $read.Ok) {
        $result.Error = ('{0}: 清单正文缓存无法读取（{1}）' -f $name, [string]$read.Error)
        return $result
    }
    $result.Entries = @(Get-ManifestEntries -Manifest $read.Value)
    return $result
}
