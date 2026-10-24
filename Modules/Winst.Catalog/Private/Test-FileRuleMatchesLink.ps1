#Requires -Version 5.1

function Test-FileRuleMatchesLink {
    <#
    .SYNOPSIS
        判断页面上的候选链接是否命中 page 源的文件名匹配规则。
    .DESCRIPTION
        规则同时作用于链接地址与其文件名：*.exe 这类按结尾写的规则两者都能命中，
        rufus* 这类按文件名开头写的规则靠文件名命中；任一命中即算命中。
    #>
    param($Rule, [string]$Text)

    if ($null -eq $Rule -or -not $Rule.Ok) { return $true }
    if (-not $Text) { return $false }
    if (Test-CompiledMatchRule -Rule $Rule -Text $Text) { return $true }
    $fileName = Get-FileNameFromUrl -Url $Text
    if ($fileName) { return (Test-CompiledMatchRule -Rule $Rule -Text $fileName) }
    return $false
}
