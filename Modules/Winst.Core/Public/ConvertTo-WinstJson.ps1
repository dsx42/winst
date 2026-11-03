#Requires -Version 5.1

function ConvertTo-WinstJson {
    <#
    .SYNOPSIS
        序列化为 JSON 文本（UTF-8 无 BOM 写出前的最后一步），并还原被转义的可读字符。
    .DESCRIPTION
        Windows PowerShell 5.1 的 ConvertTo-Json 基于 JavaScriptSerializer，会把 `<` `>` `&` `'`
        转义为 \uXXXX；这些字符在 JSON 字符串中无需转义，还原后可让清单 / 解析锁中的 URL
        （常含 `&`）保持原样可读。仅还原上述四种，不动 \" \\ 等必要转义。
    #>
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [int]$Depth = 12
    )

    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth
    if ($null -eq $json) { return '' }
    # 只匹配偶数个反斜杠之后的真正转义，保留字面量 \\uXXXX。
    $json = [regex]::Replace($json, '(?<!\\)((?:\\\\)*)\\u(003c|003e|0026|0027)', {
        param($match)
        $character = [char][Convert]::ToInt32($match.Groups[2].Value, 16)
        return $match.Groups[1].Value + [string]$character
    })
    return $json
}
