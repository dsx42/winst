#Requires -Version 5.1

function Get-WinstCompanionVersionLines {
    <#
    .SYNOPSIS
        按附加文件的比较项生成本地版本说明，不联网；安装快照与下载索引分别读取。
    #>
    param([hashtable]$Context, [string]$Id, $Row, $Ledger, $CacheIndex = $null, $Plan = $null)

    if (-not $Context) { return @() }
    if ($null -eq $Plan -and $Row) {
        $planEntry = Get-WinstRowBestPlanEntry -Row $Row
        $Plan = Get-EntryValue -Entry $planEntry -Key 'Plan'
    }
    $download = Get-EntryValue -Entry $Plan -Key 'download'
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    $declarations = New-WinstOrdinalDictionary
    for ($i = 1; $i -lt $files.Count; $i++) {
        $name = Get-EntryString -Entry $files[$i] -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url (Get-EntryString -Entry $files[$i] -Key 'url') }
        if ($name) { $declarations[$name] = $files[$i] }
    }
    $cached = $null
    if ($declarations.Count) {
        if ($null -eq $CacheIndex) { $CacheIndex = (Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($Id)).Index }
        if ($CacheIndex.Contains($Id)) { $cached = $CacheIndex[$Id] }
    }
    $snapshots = Get-EntryValue -Entry $Ledger -Key 'appliedFileVersions'
    foreach ($kind in @('已安装附件', '已下载附件')) {
        $names = @()
        if ($kind -eq '已安装附件') {
            if ($snapshots) { $names = @($snapshots.Keys) }
        } else { $names = @($declarations.Keys) }
        foreach ($name in $names) {
            if ($kind -eq '已安装附件') {
                $decl = $snapshots[$name]
                $meta = Get-WinstFileMeta -Entry @{ fileMeta = $snapshots } -FileName $name
            } else {
                $decl = $declarations[$name]
                $meta = Get-WinstFileMeta -Entry $cached -FileName $name
            }
            if (-not $meta.Exists) { continue }
            $parts = @()
            if ($meta.SourceVersion) { $parts += ('版本 {0}' -f $meta.SourceVersion) }
            $criteria = Get-WinstFileCompareCriteria -Text (Get-EntryString -Entry $decl -Key 'compare')
            foreach ($criterion in $criteria.Criteria) {
                switch ($criterion) {
                    'etag' { if ($meta.ETag) { $parts += ('ETag {0}' -f $meta.ETag) } }
                    'lastmodified' { if ($meta.LastModified) { $parts += ('修改时间 {0}' -f $meta.LastModified) } }
                    'size' { if ($null -ne $meta.Size) { $parts += ('大小 {0} 字节' -f $meta.Size) } }
                    'checksum' { if ($meta.ExpectedHash) { $parts += ('{0} {1}' -f $meta.ExpectedAlgorithm, $meta.ExpectedHash) } }
                }
            }
            if ($parts.Count) { '{0} {1}: {2}' -f $kind, $name, ($parts -join ' · ') }
        }
    }
}
