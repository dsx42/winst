#Requires -Version 5.1

function ConvertTo-WinstKeepRule {
    param([string[]]$Keep)
    foreach ($item in $Keep) {
        $pattern = ([string]$item).Trim().Replace('/', '\').Trim('\')
        if (-not $pattern) { continue }
        $expression = [regex]::Escape($pattern).Replace('\*\*', '.*').Replace('\*', '[^\\]*').Replace('\?', '[^\\]')
        @{ Regex = [regex]::new('^' + $expression + '$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
           MatchName = -not $pattern.Contains('\') }
    }
}
