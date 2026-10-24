#Requires -Version 5.1

function ConvertTo-WinstTextValue {
    <#
    .SYNOPSIS
        把 JSON 反序列化得到的标量规范化为文本。
    .DESCRIPTION
        Windows PowerShell 5.1 的 ConvertFrom-Json 会把 ISO 8601 形状的字符串（如 fetchedAt /
        resolvedAt，以及日历版本号 2026-09-11）自动转换为 DateTime；此处统一还原为 's'
        （yyyy-MM-ddTHH:mm:ss）形式的文本，避免落成随区域设置变化的本地化格式而影响比较与展示。
    #>
    param($Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [DateTime]) { return ([DateTime]$Value).ToString('s') }
    return ([string]$Value).Trim()
}
