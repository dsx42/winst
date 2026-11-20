#Requires -Version 5.1

function ConvertTo-WinstKeepRule {
    param([string]$Root, [string[]]$Keep)

    foreach ($value in $Keep) {
        $pattern = ([string]$value).Trim().Replace('/', '\')
        if (-not $pattern) { continue }
        $probe = Resolve-WinstSafeChildPath -Root $Root -Child ($pattern.Replace('*', 'x').Replace('?', 'x')) -Label '保留规则' -MaxSegmentLength 255
        if (-not $probe.Ok) { throw $probe.Error }
        $parts = @($pattern.Split('\') | Where-Object { $_ -and $_ -ne '.' })
        $next = $null
        for ($i = $parts.Count - 1; $i -ge 0; $i--) {
            $part = $parts[$i]
            $recursive = $part.Contains('**')
            $literal = ''
            $regex = $null
            if ($part -notmatch '[*?]') {
                $literal = $part
            } else {
                if ($recursive) {
                    # 从首个跨层通配起按完整相对路径匹配。
                    $part = $parts -join '\'
                    $next = $null
                }
                $expression = [regex]::Escape($part).Replace('\*\*', '.*').Replace('\*', '[^\\]*').Replace('\?', '[^\\]')
                $regex = [regex]::new('^' + $expression + '$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
            $next = @{ Literal = $literal; Regex = $regex; Recursive = $recursive; Next = $next }
        }
        $next
    }
}
