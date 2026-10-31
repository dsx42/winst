#Requires -Version 5.1

function New-MatchRule {
    <#
    .SYNOPSIS
        把清单里的匹配规则编译为可复用的对象（通配、re: 正则或 product: 产品名预置规则）。
    .OUTPUTS
        @{ Ok; IsRegex; Pattern; Source; Error; Kind }
    #>
    param([string]$Rule, [string]$Kind = '')

    $text = ''
    if ($null -ne $Rule) { $text = [string]$Rule }

    $result = @{ Ok = $false; IsRegex = $false; Pattern = ''; Source = $text; Error = ''; Kind = $Kind }
    if (-not $text.Trim()) { $result.Error = '匹配规则为空'; return $result }

    if (Test-RegexRuleText -Rule $text) {
        $result.IsRegex = $true
        $result.Pattern = Get-RegexRuleText -Rule $text
    } elseif ($text.TrimStart() -match '^(?i)product:') {
        # 产品别名按字面量编译，只允许完整名称及可选的数字版本后缀，避免命中名称相近的其它产品。
        $names = @()
        $body = $text.Substring($text.IndexOf(':') + 1)
        foreach ($part in $body.Split('|')) {
            $name = $part.Trim()
            if (-not $name) {
                $result.Error = 'product: 预置规则的产品名不能为空'
                return $result
            }
            $names += [regex]::Escape($name)
        }
        $result.Pattern = '\A(?:' + ($names -join '|') + ')(?:\s+\d+(?:\.\d+)*)?\z'
    } else {
        $result.Pattern = Convert-WildcardToRegexPattern -Wildcard $text
    }

    try {
        $null = [regex]::new($result.Pattern)
        $result.Ok = $true
    } catch {
        $result.Error = ('匹配规则写错了（{0}）: {1}' -f $text, $_.Exception.Message)
    }
    return $result
}
