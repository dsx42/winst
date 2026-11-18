#Requires -Version 5.1

function Read-WinstCliOptionValue {
    <#
    .SYNOPSIS
        读取当前位置的带值选项，消费等号后的内容或紧邻的一个参数，缺值返回空串。
    #>
    param([string[]]$Tokens, [ref]$Index)

    $token = $Tokens[$Index.Value]
    $equals = $token.IndexOf('=')
    if ($equals -ge 0) { return $token.Substring($equals + 1).Trim() }
    if ($Index.Value + 1 -ge $Tokens.Count) { return '' }
    $value = $Tokens[$Index.Value + 1].Trim()
    if (-not $value -or $value.StartsWith('-')) { return '' }
    $Index.Value++
    return $value
}
