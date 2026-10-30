#Requires -Version 5.1

function Assert-WinstAppIdentityAvailable {
    <#
    .SYNOPSIS
        在下载 / 覆盖前确认软件 id 不会占用其它大小写身份的台账、缓存或目录。
    #>
    param([hashtable]$Context, [string]$Id, $State = $null, $Index = $null)

    if (-not (Test-WinstSafePathSegment -Name $Id)) { throw ('软件 id 不是合法的单层目录名：{0}' -f $Id) }
    if ($null -eq $State) { $State = (Read-WinstState -InstallRoot $Context.InstallRoot).State }
    if ($null -eq $Index) { $Index = (Read-WinstCacheIndex -PkgDir $Context.PkgDir).Index }
    $identities = @($Id)
    foreach ($key in @(@($State['Installed'].Keys) + @($Index.Keys))) {
        if ([string]$key -ieq $Id) { $identities += [string]$key }
    }
    foreach ($rootDir in @($Context.InstallRoot, $Context.PkgDir)) {
        if (-not $rootDir -or -not (Test-Path -LiteralPath $rootDir -PathType Container)) { continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $rootDir -Force -ErrorAction Stop)) {
            if ($item.Name -ieq $Id) { $identities += $item.Name }
        }
    }
    Assert-WinstDistinctIds -Ids $identities
}
