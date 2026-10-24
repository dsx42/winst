#Requires -Version 5.1

function Select-WinstUrlByFileRule {
    <#
    .SYNOPSIS
        按 files[0].file 的通配规则过滤候选地址（没有规则时原样返回）。
    .OUTPUTS
        [string[]]
    #>
    param($Urls, $FileRule)

    $list = @($Urls)
    if (-not $FileRule) { return $list }
    $filtered = @()
    foreach ($candidate in $list) {
        if (Test-FileRuleMatchesLink -Rule $FileRule -Text $candidate) { $filtered += $candidate }
    }
    return $filtered
}
