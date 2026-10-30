#Requires -Version 5.1

function Test-WinstManifestSourceMayContainId {
    <#
    .SYNOPSIS
        用清单正文判断未解析 id 的归属；远程正文缺失 / 损坏 / 过期时允许刷新确认。
    #>
    param([hashtable]$Context, $Source, [string]$Id)

    if (Get-EntryBool -Entry $Source -Key 'isLocal') {
        return (Test-WinstLocalManifestHasId -Context $Context -Id $Id)
    }
    $name = Get-EntryString -Entry $Source -Key 'name'
    $path = Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $name
    if (-not $path) { return $true }
    $read = Read-WinstJsonFileCached -Path $path
    if (-not $read.Ok -or $null -eq $read.Value) { return $true }
    foreach ($entry in @(Get-ManifestEntries -Manifest $read.Value)) {
        if ((Get-EntryString -Entry $entry -Key 'id') -ceq $Id) { return $true }
    }
    $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $name
    $ttl = [int](Get-ConfigValue -Config $Context.Config -Key 'manifestTTLHours' -Default 24)
    $stamp = [datetime]::MinValue
    if (-not $meta -or -not [datetime]::TryParse([string]$meta.FetchedAt, [ref]$stamp)) { return $true }
    return ($ttl -le 0 -or ((Get-Date) - $stamp).TotalHours -ge $ttl)
}
