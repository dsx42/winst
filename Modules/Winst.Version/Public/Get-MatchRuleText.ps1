#Requires -Version 5.1

function Get-MatchRuleText {
    <#
    .SYNOPSIS
        展开匹配规则里的 {version} / {tag} 占位符（正则写法按字面量插入，通配写法直接替换）。
    .OUTPUTS
        展开后的规则文本（保留 re: 前缀）
    #>
    param([string]$Rule, [string]$Version = '', [string]$Tag = '')

    if ($null -eq $Rule) { return '' }
    $text = [string]$Rule

    if (Test-RegexRuleText -Rule $text) {
        $body = Get-RegexRuleText -Rule $text
        $body = Replace-PlaceholderLiteral -Text $body -Name 'version' -Value $Version -Escape
        $body = Replace-PlaceholderLiteral -Text $body -Name 'tag' -Value $Tag -Escape
        return ('re:' + $body)
    }

    $text = Replace-PlaceholderLiteral -Text $text -Name 'version' -Value $Version
    $text = Replace-PlaceholderLiteral -Text $text -Name 'tag' -Value $Tag
    return $text
}
