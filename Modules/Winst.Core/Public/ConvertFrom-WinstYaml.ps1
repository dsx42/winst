#Requires -Version 5.1

function ConvertFrom-WinstYaml {
    <#
    .SYNOPSIS
        按实际缩进读取单份块式 YAML，保留字段大小写、序列项数和标量文本。
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $tokens = New-Object 'System.Collections.Generic.List[object]'
    $number = 0
    $scalarParentIndent = $null
    $keySeparator = ':(?=[ \t]|$)'
    if ($Text.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal)) { $Text = $Text.Substring(1) }
    foreach ($line in ($Text -split '\r\n|\r|\n')) {
        $number++
        if ($line -match '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x84\x86-\x9F\uFEFF\uFFFE\uFFFF]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]') {
            throw "YAML 第 $number 行：语法错误，行内含有非法字符。"
        }
        # 只有行首或分隔空白后的井号才引入注释。
        $commentParts = $line -split '(?:^|(?<=[ \t]))#', 2
        $content = $commentParts[0].TrimEnd([char[]]" `t")
        if ($content.Length -eq 0) {
            if ($commentParts.Count -gt 1) { $scalarParentIndent = $null }
            continue
        }
        if ($content -match '^(?:---|\.\.\.)(?:[ \t]|$)') { throw "YAML 第 $number 行：暂不支持文档标记或多文档流。" }

        $body = $content.TrimStart(' ')
        $indent = $content.Length - $body.Length
        # 续行中的短横线可以是文本，须在识别序列项前按标量上下文判断。
        if ($null -ne $scalarParentIndent -and $indent -gt $scalarParentIndent -and $body -notmatch $keySeparator) {
            throw "YAML 第 $number 行：暂不支持多行标量。"
        }
        $scalarParentIndent = $null
        if ($content -match '^ *\t') { throw "YAML 第 $number 行：语法错误，缩进只能使用空格。" }
        if ($body -match '^-(?:[ \t]|$)') {
            $tokens.Add(@{ Kind = 'Item'; Indent = $indent; Number = $number })
            if ($body.Length -eq 1) { continue }
            # 将短横线和同一行上的映射拆开，后续字段与该键的实际列对齐。
            if ($body -match '^- *\t') { throw "YAML 第 $number 行：语法错误，序列项的映射缩进只能使用空格。" }
            $body = $body.Substring(1).TrimStart(' ')
            $indent = $content.Length - $body.Length
            if ($body -match '^-(?:[ \t]|$)') { throw "YAML 第 $number 行：暂不支持嵌套的序列项。" }
        }

        $parts = $body -split $keySeparator, 2
        $key = $parts[0].TrimEnd([char[]]" `t")
        Assert-WinstYamlPlainScalar -Value $key -Number $number
        if ($parts.Count -eq 1) {
            $scalarParentIndent = if ($tokens.Count) { $tokens[$tokens.Count - 1].Indent } else { -1 }
            $tokens.Add(@{ Kind = 'Scalar'; Indent = $indent; Number = $number; Value = $key })
        } else {
            # YAML 的隐式键最多包含 1024 个 Unicode 字符，代理项对只计一次。
            if ($parts[0].Length -gt 1024 -and ($parts[0] -creplace '[\uD800-\uDBFF]', '').Length -gt 1024) {
                throw "YAML 第 $number 行：语法错误，隐式键超出 1024 个字符。"
            }
            $value = $parts[1].TrimStart([char[]]" `t")
            if ($value.Length -gt 0) {
                Assert-WinstYamlPlainScalar -Value $value -Number $number
                $scalarParentIndent = $indent
            }
            $tokens.Add(@{ Kind = 'Entry'; Indent = $indent; Number = $number; Key = $key; Value = $value })
        }
        if ($commentParts.Count -gt 1) { $scalarParentIndent = $null }
    }

    if ($tokens.Count -eq 0) { throw 'YAML 第 1 行：暂不支持空文档。' }
    $reader = @{ Tokens = $tokens; Index = 0 }
    $result = Read-WinstYamlBlock -Reader $reader
    if ($reader.Index -lt $tokens.Count) {
        $extra = $tokens[$reader.Index]
        throw "YAML 第 $($extra.Number) 行：语法错误，缩进或节点类型与根节点不一致。"
    }
    return ,$result
}
