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
    # 每个 HTML 容器只读一次。Parent 表示最近的父容器，Preferred 优先选择整行或列表项。
    $containers = New-Object 'System.Collections.Generic.List[object]'
    $open = New-Object 'System.Collections.Generic.List[object]'
    $tags = [regex]'(?is)<(?<close>/)?(?<tag>tr|li|article|p|div|td|section)\b[^>]*>'
    for ($tag = $tags.Match($Text); $tag.Success; $tag = $tag.NextMatch()) {
        $tagName = $tag.Groups['tag'].Value.ToLowerInvariant()
        if ($tag.Groups['close'].Success) {
            for ($i = $open.Count - 1; $i -ge 0; $i--) {
                if ($open[$i].Name -ne $tagName) { continue }
                for ($j = $i; $j -lt $open.Count; $j++) { $open[$j].ClosedAt = $tag.Index }
                $open[$i].End = $tag.Index
                $open.RemoveRange($i, $open.Count - $i)
                break
            }
        } elseif (-not $tag.Value.EndsWith('/>')) {
            $parent = $null
            $preferred = $null
            if ($open.Count) { $parent = $open[$open.Count - 1]; $preferred = $parent.Preferred }
            $node = @{ OpenEnd = $tag.Index + $tag.Length; End = -1; ClosedAt = $Text.Length
                Name = $tagName; Parent = $parent; Preferred = $preferred }
            if ($tagName -in @('tr', 'li', 'article', 'p')) { $node.Preferred = $node }
            $containers.Add($node)
            $open.Add($node)
        }
    }
    $isHtml = $Text.IndexOf('<') -ge 0
    $nextContainer = 0
    $active = $null
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

        while ($nextContainer -lt $containers.Count -and $containers[$nextContainer].OpenEnd -le $index) {
            $active = $containers[$nextContainer]
            $nextContainer++
        }
        while ($null -ne $active -and $active.ClosedAt -le $index) { $active = $active.Parent }
        if ($null -ne $active) {
            $container = $active
            if ($null -ne $active.Preferred) { $container = $active.Preferred }
            if ($container.End -ge 0) { $end = $container.End }
        }
        if ($end -le $offset) { continue }
        $window = $Text.Substring($offset, $end - $offset)
        # 命中可能在 href 属性内；去掉属性余部与标签，只检查后面的可读内容。
        if ($isHtml -and $Text.LastIndexOf('<', $index) -gt $Text.LastIndexOf('>', $index)) { $window = $window -replace '^[^>]*>', '' }
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
