#Requires -Version 5.1

function Get-WinstSearchCatalog {
    <#
    .SYNOPSIS
        按关键字搜索全部软件源，结果按 id 合并成行（同 id 的多个来源列在同一行）。
    .DESCRIPTION
        匹配范围：id / 名称 / 说明的**子串**（不区分大小写）；关键字为空时返回全部软件。
        每行含各来源与其版本，供「列出软件源和软件版本」使用。
    .OUTPUTS
        @( [ordered]@{ Id; Name; Description; Sources = @( @{ Source; Version; Ok; Error; Plan } ) } )
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Keyword = '',
        [string[]]$Ids
    )

    $keywordText = $Keyword.Trim()

    # 搜索各来源的名称和说明后再合并，同一 id 可以只命中部分来源。
    $filtered = $PSBoundParameters.ContainsKey('Ids')
    $cache = Get-WinstState -Name WinstSearchCatalogCache
    if (-not $filtered -and -not $keywordText -and $null -ne $cache) { return $cache }

    $groups = New-WinstOrdinalDictionary
    if ($filtered) {
        $wanted = New-WinstOrdinalDictionary
        foreach ($id in $Ids) { $wanted[$id] = $true }
        $records = @(foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
            $sourceName = [string]$source['name']
            foreach ($app in @(Get-ManifestResolvedApps -PkgDir $Context.PkgDir -Name $sourceName)) {
                if ($wanted.Contains((Get-EntryString -Entry $app -Key 'id'))) { @{ Source = $sourceName; App = $app } }
            }
        })
    } else { $records = @(Get-WinstAllResolvedApps -Context $Context) }
    foreach ($item in $records) {
        $app = $item['App']
        $id = Get-EntryString -Entry $app -Key 'id'
        if (-not $id) { continue }

        if ($keywordText) {
            $name = Get-EntryString -Entry $app -Key 'name'
            $description = Get-EntryString -Entry $app -Key 'description'
            $hit = $id.IndexOf($keywordText, [StringComparison]::OrdinalIgnoreCase) -ge 0
            if (-not $hit -and $name) { $hit = $name.IndexOf($keywordText, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
            if (-not $hit -and $description) { $hit = $description.IndexOf($keywordText, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
            if (-not $hit) { continue }
        }

        if (-not $groups.Contains($id)) {
            $groups[$id] = [ordered]@{
                Id          = $id
                Name        = (Get-EntryString -Entry $app -Key 'name')
                Description = (Get-EntryString -Entry $app -Key 'description')
                Sources     = @()
            }
        }
        $row = $groups[$id]
        if (-not $row['Name']) { $row['Name'] = (Get-EntryString -Entry $app -Key 'name') }
        if (-not $row['Description']) { $row['Description'] = (Get-EntryString -Entry $app -Key 'description') }
        $version = Get-EntryString -Entry $app -Key 'version'
        if ((Get-EntryBool -Entry $app -Key 'versionFromPackage') -or (Get-EntryBool -Entry $app -Key 'versionFromCache')) {
            $version = ''
            if ((Get-EntryString -Entry $app -Key 'remoteFresh') -eq 'unchanged') {
                # 锁中的比较结论只适用于当时的主包，版本从当前索引读。
                $entry = (Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($id)).Index[$id]
                $files = @(Get-EntryArray -Entry $entry -Key 'files')
                $hash = Get-EntryString -Entry $app -Key 'remoteFreshHash'
                if ($hash -and $files.Count -and (Test-WinstSafePathSegment -Name $files[0]) -and
                        (Get-WinstRecordedHash -Entry $entry -FileName $files[0]) -ieq $hash -and
                        (Test-Path -LiteralPath (Join-WinstPath (Join-WinstPath $Context.PkgDir $id) $files[0]) -PathType Leaf)) {
                    $version = Get-EntryString -Entry $entry -Key 'version'
                } else {
                    $app = Copy-WinstObjectShallow -InputObject $app
                    $app['remoteFresh'] = 'unknown'
                }
            }
        }
        $row['Sources'] += @{
            Source  = [string]$item['Source']
            Version = $version
            Ok      = (Get-EntryBool -Entry $app -Key 'ok')
            Error   = (Get-EntryString -Entry $app -Key 'error')
            Plan    = $app
        }
    }

    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($id in @($groups.Keys | Sort-Object)) {
        $row = $groups[$id]
        $row['Group'] = Get-WinstRowGroup -Row $row
        $rows.Add($row)
    }
    $finalRows = @($rows.ToArray())
    if (-not $filtered -and -not $keywordText) {
        $null = Set-WinstState -Name WinstSearchCatalogCache -Value $finalRows
    }
    return $finalRows
}
