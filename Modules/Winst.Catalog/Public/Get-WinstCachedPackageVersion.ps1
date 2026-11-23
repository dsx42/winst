#Requires -Version 5.1

function Get-WinstCachedPackageVersion {
    <#
    .SYNOPSIS
        核对主包与取版文件的来源，读取已登记的版本或按当前规则重读本地包。
    #>
    param([hashtable]$Context, $Plan, $Entry, [string]$MainHash, [switch]$Offline, $MainFilePlan, [ref]$MatchedMainHash)

    if ($null -ne $MatchedMainHash) { $MatchedMainHash.Value = '' }
    $pkgDir = $Context.PkgDir

    $id = Get-EntryString -Entry $Plan -Key 'id'
    if (-not $PkgDir -or -not (Test-WinstSafePathSegment -Name $id)) { return '' }
    if (-not $PSBoundParameters.ContainsKey('Entry')) {
        $read = Read-WinstCacheIndex -PkgDir $PkgDir -Ids @($id)
        if ($read.Error) { return '' }
        $Entry = $read.Index[$id]
    }
    $versionInput = Get-WinstPackageVersionInput -Plan $Plan
    if (-not $versionInput) { return '' }
    $files = @(Get-EntryArray -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files')
    $dir = Join-WinstPath $PkgDir $id
    $origin = Get-EntryString -Entry $Plan -Key 'manifestOrigin'
    foreach ($i in @(0, $versionInput.Index) | Select-Object -Unique) {
        $url = Get-EntryString -Entry $files[$i] -Key 'url'
        $name = Get-EntryString -Entry $files[$i] -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url $url }
        $name = $name.Trim()
        if (-not (Test-WinstSafePathSegment -Name $name) -or
                -not (Test-Path -LiteralPath (Join-WinstPath $dir $name) -PathType Leaf)) { return '' }
        $hash = Get-WinstRecordedHash -Entry $Entry -FileName $name
        if (-not $hash) { return '' }
        $meta = Get-WinstFileMeta -Entry $Entry -FileName $name
        if ($meta.ManifestOrigin -and $meta.ManifestOrigin -cne $origin) { return '' }
        if ($i -eq 0 -and $MainHash) {
            if ($hash -ine $MainHash) { return '' }
            # 即使新取版附件尚未下载，已核实的主包仍可与安装基线比较。
            if ($null -ne $MatchedMainHash -and $meta.ManifestOrigin) { $MatchedMainHash.Value = $hash }
        } elseif ((-not $Offline -and -not $meta.ManifestOrigin -and -not $meta.Url) -or
                ($meta.Url -and $meta.Url -cne $url -and -not ($Offline -and $meta.ManifestOrigin))) {
            return ''
        }
    }
    $version = (Get-EntryString -Entry $Entry -Key 'version').Trim()
    $versionFile = Get-EntryString -Entry $Entry -Key 'versionFile'
    $rule = Get-EntryValue -Entry $Entry -Key 'versionRule'
    if ($version -and $versionInput.Name -ieq $versionFile -and
            (Test-WinstJsonValueEqual -Left $rule -Right (Get-WinstPackageVersionRule -Plan $Plan))) { return $version }

    # 离线单文件旧计划已按自身规则确认版本，主包摘要通过且单文件索引版本吻合时可补写规则。
    if ($MainFilePlan) {
        if ($Offline -and $null -eq $rule -and (-not $versionFile -or $versionInput.Name -ieq $versionFile) -and
                $files.Count -eq 1 -and @(Get-EntryArray -Entry $Entry -Key 'files').Count -eq 1 -and $MainFilePlan.ExpectedHash -and
                $version -and $MainFilePlan.CachedVersion -ceq $version -and
                (Get-EntryBool -Entry $Plan -Key 'versionFromCache') -and
                (Get-EntryString -Entry $Plan -Key 'version') -ceq $version) { return $version }
        return ''
    }
    $read = Get-WinstPackageDerivedVersion -Context $Context -PkgDir $dir -Plan $Plan -FileName $versionInput.Name
    if ($read.Ok) { return $read.Version }
    return ''
}
