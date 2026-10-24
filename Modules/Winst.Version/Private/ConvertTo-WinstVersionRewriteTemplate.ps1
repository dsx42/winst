#Requires -Version 5.1

function ConvertTo-WinstVersionRewriteTemplate {
    <#
    .SYNOPSIS
        把「写法模板」{ from, to } 编译成等价的正则规则 { pattern, replace }。
    .DESCRIPTION
        from / to 里用 {名字} 表示「这里是一段内容」，同名占位在两边对应同一段内容，其余文字按字面量匹配。
        匹配规则：从版本号开头匹配；from 中间的字面量必须原样出现；最后一个占位吃到结尾
        （所以 jdk8u{r}-b{b} 配 jdk8u412-b08.1 会得到 1.8.0_412-b08.1，多出来的后缀不会丢）；
        from 以固定文字结尾时，要求版本号也以此结尾。编译结果就是 pattern / replace，与正则写法完全等价。
    .OUTPUTS
        @{ Ok; Rule = [ordered]@{ pattern; replace }; Error }
    #>
    param([string]$From, [string]$To)

    $result = @{ Ok = $false; Rule = $null; Error = '' }
    $fromText = ''
    if ($null -ne $From) { $fromText = [string]$From }
    $toText = ''
    if ($null -ne $To) { $toText = [string]$To }

    # —— 解析 from：拆成「字面量」与「占位」 ——
    $parts = @()
    $literal = ''
    $index = 0
    while ($index -lt $fromText.Length) {
        $ch = $fromText[$index]
        if ($ch -eq '{') {
            $end = $fromText.IndexOf('}', $index + 1)
            if ($end -lt 0) {
                $result.Error = ('from 里的占位符没有闭合的 }}: {0}' -f $fromText)
                return $result
            }
            $name = $fromText.Substring($index + 1, $end - $index - 1).Trim()
            if (-not ($name -match '^[A-Za-z_][A-Za-z0-9_]*$')) {
                $result.Error = ('from 里的占位符名字不合法: {{{0}}}（只能用字母 / 数字 / 下划线，且以字母或下划线开头）' -f $name)
                return $result
            }
            if ($literal) {
                $parts += [ordered]@{ Kind = 'text'; Value = $literal }
                $literal = ''
            }
            $parts += [ordered]@{ Kind = 'slot'; Value = $name }
            $index = $end + 1
            continue
        }
        if ($ch -eq '}') {
            $result.Error = ('from 里出现了多余的 }}: {0}' -f $fromText)
            return $result
        }
        $literal += $ch
        $index++
    }
    if ($literal) { $parts += [ordered]@{ Kind = 'text'; Value = $literal } }

    $slotNames = @()
    foreach ($part in $parts) {
        if ($part['Kind'] -eq 'slot') { $slotNames += [string]$part['Value'] }
    }
    if ($slotNames.Count -eq 0) {
        $result.Error = ('from 里至少要有一个占位（如 jdk8u{u}-b{b}）；只去前缀 / 后缀请写 { "stripPrefix": "…" }')
        return $result
    }
    foreach ($name in $slotNames) {
        $sameCount = 0
        foreach ($slot in $slotNames) { if ($slot -ceq $name) { $sameCount++ } }
        if ($sameCount -gt 1) {
            $result.Error = ('from 里的占位 {{{0}}} 出现了多次，请换一个名字' -f $name)
            return $result
        }
    }

    # —— 生成 pattern：中间占位尽量少取，末位占位吃到结尾 ——
    $pattern = '^'
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $part = $parts[$i]
        if ($part['Kind'] -eq 'text') {
            $pattern += [regex]::Escape([string]$part['Value'])
            continue
        }
        if ($i -eq ($parts.Count - 1)) {
            $pattern += ('(?<{0}>.*)' -f $part['Value'])
        } else {
            $pattern += ('(?<{0}>.*?)' -f $part['Value'])
        }
    }
    if ($parts[$parts.Count - 1]['Kind'] -eq 'text') { $pattern += '$' }

    # —— 生成 replace：{名字} → ${名字}，字面量里的 $ 需转义为 $$ ——
    $replacement = ''
    $index = 0
    while ($index -lt $toText.Length) {
        $ch = $toText[$index]
        if ($ch -eq '{') {
            $end = $toText.IndexOf('}', $index + 1)
            if ($end -lt 0) {
                $result.Error = ('to 里的占位符没有闭合的 }}: {0}' -f $toText)
                return $result
            }
            $name = $toText.Substring($index + 1, $end - $index - 1).Trim()
            $exists = $false
            foreach ($slot in $slotNames) { if ($slot -ceq $name) { $exists = $true; break } }
            if (-not $exists) {
                $result.Error = ('to 里用了 from 中没有的占位 {{{0}}}；from = {1}' -f $name, $fromText)
                return $result
            }
            $replacement += ('${{{0}}}' -f $name)
            $index = $end + 1
            continue
        }
        if ($ch -eq '}') {
            $result.Error = ('to 里出现了多余的 }}: {0}' -f $toText)
            return $result
        }
        if ($ch -eq '$') { $replacement += '$$' } else { $replacement += $ch }
        $index++
    }

    try {
        $null = New-Object System.Text.RegularExpressions.Regex($pattern)
    } catch {
        $result.Error = ('这个写法无法编译成匹配规则（from = {0}）：{1}' -f $fromText, $_.Exception.Message)
        return $result
    }

    $result.Rule = [ordered]@{ pattern = $pattern; replace = $replacement }
    $result.Ok = $true
    return $result
}
