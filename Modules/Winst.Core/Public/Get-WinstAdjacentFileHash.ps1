#Requires -Version 5.1

function Get-WinstAdjacentFileHash {
    <#
    .SYNOPSIS
        在文件名所在文本行或 HTML 条目内读取相邻摘要，不跨到另一文件条目。
    .OUTPUTS
        @{ Ok; Hash; Error }；不同命中位置给出不同摘要时明确失败。
    #>
    param([string]$Text, [string]$FileName)

    $result = @{ Ok = $false; Hash = ''; Error = '' }
    $name = ([string]$FileName).Trim()
    if (-not $name -or -not $Text) { $result.Error = '缺少文件名或校验内容'; return $result }
    $hashes = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $offset = 0
    while ($offset -lt $Text.Length) {
        $index = $Text.IndexOf($name, $offset, [StringComparison]::OrdinalIgnoreCase)
        if ($index -lt 0) { break }
        $offset = $index + $name.Length
        # 比较完整文件名字段，不能把 other-foo.zip / foo.zip.sig 的摘要归给 foo.zip。
        $fieldStart = 0
        if ($index -gt 0) {
            $fieldStart = $Text.LastIndexOfAny([char[]]@(13, 10, 9, 60, 62, 34, 39, 47, 92, 58, 124, 40, 91), $index - 1) + 1
        }
        if ($Text.Substring($fieldStart, $index - $fieldStart).Trim()) { continue }
        if ($offset -lt $Text.Length -and $Text[$offset] -notmatch '[\s<>"''\)\]\|?:#]') { continue }
        $end = $Text.IndexOfAny([char[]]@("`r", "`n"), $offset)
        if ($end -lt 0) { $end = $Text.Length }

        # HTML 按仍在栈中的条目限定范围；表格优先整行，允许摘要位于下一列。
        $stack = New-Object 'System.Collections.Generic.List[object]'
        foreach ($tag in [regex]::Matches($Text.Substring(0, $index), '(?is)<(?<close>/)?(?<tag>tr|li|article|p|div|td|section)\b[^>]*>')) {
            $tagName = $tag.Groups['tag'].Value.ToLowerInvariant()
            if ($tag.Groups['close'].Success) {
                for ($s = $stack.Count - 1; $s -ge 0; $s--) {
                    if ($stack[$s].Name -eq $tagName) { $stack.RemoveRange($s, $stack.Count - $s); break }
                }
            } elseif (-not $tag.Value.EndsWith('/>')) {
                $stack.Add(@{ Name = $tagName; Start = $tag.Index })
            }
        }
        $container = $null
        for ($s = $stack.Count - 1; $s -ge 0; $s--) {
            if ($stack[$s].Name -in @('tr', 'li', 'article', 'p')) { $container = $stack[$s]; break }
        }
        if (-not $container -and $stack.Count -gt 0) { $container = $stack[$stack.Count - 1] }
        if ($container) {
            $depth = 0
            $pattern = '(?is)<(?<close>/)?' + [regex]::Escape([string]$container.Name) + '\b[^>]*>'
            foreach ($tag in [regex]::Matches($Text.Substring([int]$container.Start), $pattern)) {
                if ($tag.Groups['close'].Success) { $depth-- } elseif (-not $tag.Value.EndsWith('/>')) { $depth++ }
                if ($depth -eq 0) { $end = [int]$container.Start + $tag.Index; break }
            }
        }
        if ($end -le $offset) { continue }
        $window = $Text.Substring($offset, $end - $offset)
        # 命中可能在 href 属性内；去掉属性余部与标签，只检查后面的可读内容。
        if ($Text.LastIndexOf('<', $index) -gt $Text.LastIndexOf('>', $index)) { $window = $window -replace '^[^>]*>', '' }
        $window = [Net.WebUtility]::HtmlDecode(($window -replace '(?s)<[^>]*>', ' '))
        foreach ($next in [regex]::Matches($window, '(?i)[^\s<>"'']+\.(?:exe|msi|zip|7z|rar|cab|tar|gz|xz|bz2|iso|img|msix|appx|jar|apk|dmg|deb|rpm|pkg|bin)\b')) {
            $nextName = [IO.Path]::GetFileName($next.Value.Replace('/', '\'))
            if ($nextName -ine $name) { $window = $window.Substring(0, $next.Index); break }
        }
        $digest = [regex]::Match($window, '(?i)(?<![0-9a-f])(?:[0-9a-f]{128}|[0-9a-f]{64}|[0-9a-f]{40}|[0-9a-f]{32})(?![0-9a-f])')
        if ($digest.Success) { $null = $hashes.Add($digest.Value.ToLowerInvariant()) }
    }
    if ($hashes.Count -eq 1) { $result.Ok = $true; foreach ($hash in $hashes) { $result.Hash = $hash }; return $result }
    if ($hashes.Count -gt 1) { $result.Error = ('文件 {0} 对应多个不同摘要，无法确定归属' -f $name) }
    else { $result.Error = ('文件 {0} 所在条目没有可识别的摘要' -f $name) }
    return $result
}
