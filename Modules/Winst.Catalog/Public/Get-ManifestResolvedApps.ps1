#Requires -Version 5.1

function Get-ManifestResolvedApps {
    <#
    .SYNOPSIS
        读取某软件源的解析锁（apps 数组）；没有 apps 字段时返回空数组。
    #>
    param([string]$PkgDir, [string]$Name)

    $meta = Read-ManifestMeta -PkgDir $PkgDir -Name $Name
    if (-not $meta -or -not $meta.HasApps) { return @() }
    return @($meta.Apps)
}
