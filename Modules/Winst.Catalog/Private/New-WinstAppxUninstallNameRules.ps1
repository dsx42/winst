#Requires -Version 5.1

function New-WinstAppxUninstallNameRules {
    <#
    .SYNOPSIS
        展开并校验应用包卸载名称规则，保留字符串或数组形态。
    .OUTPUTS
        @{ Value; Error }
    #>
    param($NameRules, [string]$Version)

    $result = @{ Value = $null; Error = '' }
    $isSingle = $NameRules -is [string]
    if (-not $isSingle -and ($NameRules -isnot [System.Collections.IEnumerable] -or $NameRules -is [System.Collections.IDictionary])) {
        $result.Error = 'uninstall.name 必须是字符串或字符串数组'
        return $result
    }

    $names = @()
    foreach ($rawName in @($NameRules)) {
        if ($rawName -isnot [string] -or -not $rawName.Trim()) {
            $result.Error = 'uninstall.name 的每条名称规则都必须是非空字符串'
            return $result
        }
        $name = $rawName.Trim()
        $isRegex = Test-RegexRuleText -Rule $name
        $isProduct = (-not $isRegex -and $name.TrimStart() -match '^(?i)product:')
        # 正则的数字量词、Unicode 属性和转义花括号保持原义；版本模板拼写错误必须明确报错。
        foreach ($token in [regex]::Matches($name, '(?<!\\)\{([A-Za-z][A-Za-z0-9]*)\}')) {
            $tokenName = $token.Groups[1].Value
            if (@('version', 'versionMajor') -cnotcontains $tokenName -and (-not $isRegex -or $tokenName -match '^(?i)version')) {
                $result.Error = ('uninstall.name 含有不支持的占位符：{0}；只支持 {{version}} / {{versionMajor}}' -f $token.Value)
                return $result
            }
        }
        $versionPattern = '(?<!\\)\{version(Major)?\}'
        if ([regex]::IsMatch($name, $versionPattern)) {
            $versionText = ([string]$Version).Trim()
            if (-not $versionText) {
                $result.Error = 'uninstall.name 使用了版本占位符，但没有可用版本号'
                return $result
            }
            $majorText = ($versionText -split '\.')[0]
            # 版本值始终按字面量插入；正则的点号、通配的星号不能扩大卸载范围。
            if ($isRegex) {
                $versionText = [regex]::Escape($versionText)
                $majorText = [regex]::Escape($majorText)
            } elseif ($isProduct) {
                if ($versionText.Contains('|')) {
                    $result.Error = 'uninstall.name 的 product: 版本占位符不能包含别名分隔符 |'
                    return $result
                }
            } else {
                $versionText = ConvertTo-WildcardLiteral -Text $versionText
                $majorText = ConvertTo-WildcardLiteral -Text $majorText
            }
            $name = [regex]::Replace($name, $versionPattern, [Text.RegularExpressions.MatchEvaluator]{
                    param($match)
                    if ($match.Groups[1].Success) { return $majorText }
                    return $versionText
                })
        }
        # 模板值不能把普通通配规则变成另一种处理器，否则原本的字面值可能获得正则语义。
        $expandedIsRegex = Test-RegexRuleText -Rule $name
        $expandedIsProduct = (-not $expandedIsRegex -and $name.TrimStart() -match '^(?i)product:')
        if ($expandedIsRegex -ne $isRegex -or $expandedIsProduct -ne $isProduct) {
            $result.Error = 'uninstall.name 的版本占位符不能改变匹配规则类型'
            return $result
        }
        $compiled = New-MatchRule -Rule $name -Kind '应用包名称'
        if (-not $compiled.Ok) {
            $result.Error = ('uninstall.name 写错了：{0}' -f $compiled.Error)
            return $result
        }
        $names += $name
    }
    if ($names.Count -eq 0) {
        $result.Error = 'uninstall.name 至少需要一条名称规则'
        return $result
    }
    if ($isSingle) { $result.Value = [string]$names[0] } else { $result.Value = @($names) }
    return $result
}
