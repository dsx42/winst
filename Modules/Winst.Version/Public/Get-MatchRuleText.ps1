#Requires -Version 5.1

function Get-MatchRuleText {
    <#
    .SYNOPSIS
        展开匹配规则里的 {version} / {versionMajor} / {versionMinor} / {tag} 占位符（正则写法按字面量插入，通配写法直接替换）。
    .OUTPUTS
        展开后的规则文本（保留 re: 前缀）
    #>
    param([string]$Rule, [string]$Version = '', [string]$Tag = '')

    if ($null -eq $Rule) { return '' }
    $text = [string]$Rule
    $escape = Test-RegexRuleText -Rule $text
    return [regex]::Replace($text, '\{(?:version(?:Major|Minor)?|tag)\}', [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $value = if ($match.Value -ceq '{tag}') { $Tag } else { Expand-VersionPlaceholder -Text $match.Value -Version $Version }
        if ($escape) { return [regex]::Escape($value) }
        return $value
    })
}
