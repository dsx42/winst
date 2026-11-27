#Requires -Version 5.1

function Read-WinstYamlBlock {
    param([hashtable]$Reader)

    $tokens = $Reader.Tokens
    $first = $tokens[$Reader.Index]
    if ($first.Kind -eq 'Scalar') {
        $Reader.Index++
        return $first.Value
    }

    $sequence = $first.Kind -eq 'Item'
    if ($sequence) { $items = New-Object 'System.Collections.Generic.List[object]' }
    else { $map = New-WinstOrdinalDictionary }

    while ($Reader.Index -lt $tokens.Count) {
        $token = $tokens[$Reader.Index]
        if ($token.Indent -gt $first.Indent) {
            throw "YAML 第 $($token.Number) 行：语法错误，缩进与当前层不一致。"
        }
        if ($token.Indent -lt $first.Indent -or $token.Kind -ne $first.Kind) { break }
        $Reader.Index++

        if (-not $sequence -and $map.Contains($token.Key)) {
            throw "YAML 第 $($token.Number) 行：语法错误，映射含有重复键「$($token.Key)」。"
        }

        $next = if ($Reader.Index -lt $tokens.Count) { $tokens[$Reader.Index] }
        if (-not $sequence -and $token.Value.Length -gt 0) {
            $value = $token.Value
        } else {
            # 映射值的序列短横线可以与键同列，映射字段本身仍须缩进。
            $indentless = $next -and -not $sequence -and $next.Indent -eq $token.Indent -and $next.Kind -eq 'Item'
            if (-not $next -or ($next.Indent -le $token.Indent -and -not $indentless)) {
                throw "YAML 第 $($token.Number) 行：暂不支持空节点。"
            }
            if ($sequence -and $next.Kind -ne 'Entry') {
                throw "YAML 第 $($next.Number) 行：暂不支持非映射的序列项。"
            }
            $value = Read-WinstYamlBlock -Reader $Reader
        }
        if ($sequence) { $items.Add($value) }
        else { $map.Add($token.Key, $value) }
    }
    if ($sequence) { return ,$items.ToArray() }
    return $map
}
