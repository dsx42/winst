#Requires -Version 5.1

function ConvertTo-WildcardLiteral {
    <#
    .SYNOPSIS
        把字面文本转成通配写法（* ? \ 被转义为字面量），用于自动推导默认匹配规则。
    #>
    param([string]$Text)

    $literal = ''
    if ($null -ne $Text) { $literal = [string]$Text }
    return $literal.Replace('\', '\\').Replace('*', '\*').Replace('?', '\?')
}
