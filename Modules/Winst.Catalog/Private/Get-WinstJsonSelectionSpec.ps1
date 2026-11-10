#Requires -Version 5.1

function Get-WinstJsonSelectionSpec {
    <#
    .SYNOPSIS
        校验 JSON 候选的版本过滤与排序规则。
    #>
    param($Source, [string]$Label)

    foreach ($pair in @(Get-WinstEntryPairs -Entry $Source)) {
        $key = [string]$pair[0]
        if (@('versionKey', 'versionFilter', 'sort') -contains $key -and $pair[1] -isnot [string]) {
            return @{ Error = ($Label + ' 的 ' + $key + ' 必须是字符串') }
        }
    }
    $versionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    $filterText = (Get-EntryString -Entry $Source -Key 'versionFilter').Trim()
    $sort = (Get-EntryString -Entry $Source -Key 'sort').Trim().ToLowerInvariant()
    if (($filterText -or $sort) -and -not $versionKey) {
        return @{ Error = ($Label + ' 的 versionFilter / sort 必须配合 versionKey') }
    }
    if ($sort -and $sort -ne 'semver') {
        return @{ Error = ($Label + ' 的 sort 只支持 semver') }
    }
    $filterRule = $null
    if ($filterText) {
        $filterRule = New-MatchRule -Rule $filterText -Kind '版本过滤'
        if (-not $filterRule.Ok) { return @{ Error = ($Label + '：' + $filterRule.Error) } }
    }
    return @{ Error = ''; VersionKey = $versionKey; FilterRule = $filterRule; Sort = $sort }
}
