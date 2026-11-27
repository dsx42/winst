#Requires -Version 5.1

function Select-WinstUrlByFileRule {
    <#
    .SYNOPSIS
        按 files[0].file 的通配规则过滤候选地址。
    .OUTPUTS
        [string[]]
    #>
    param($Urls, [Parameter(Mandatory = $true)]$FileRule)

    foreach ($candidate in $Urls) {
        if (Test-FileRuleMatchesLink -Rule $FileRule -Text $candidate) { $candidate }
    }
}
