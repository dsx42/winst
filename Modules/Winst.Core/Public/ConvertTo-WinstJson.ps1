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

    $json = $InputObject | ConvertTo-Json -Depth $Depth
    if ($null -eq $json) { return '' }
    $json = $json -replace '\\u003c', '<'
    $json = $json -replace '\\u003e', '>'
    $json = $json -replace '\\u0026', '&'
    $json = $json -replace '\\u0027', "'"
    return $json
}
