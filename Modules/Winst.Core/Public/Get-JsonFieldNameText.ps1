#Requires -Version 5.1

function Get-JsonFieldNameText {
    <#
    .SYNOPSIS
        列出 JSON 对象 / 数组的字段名，用于「字段没找到」这类报错里展示实际有哪些字段。
    #>
    param($Node)

    if ($null -eq $Node) { return '（空）' }
    if ($Node -is [System.Array]) { return ('数组（{0} 项）' -f @($Node).Count) }

    $names = @()
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in @($Node.Keys)) { $names += [string]$key }
    } else {
        foreach ($prop in @($Node.PSObject.Properties)) { $names += [string]$prop.Name }
    }
    if ($names.Count -eq 0) { return '（没有字段）' }
    if ($names.Count -gt 8) { $names = @($names[0..7]) + @('…') }
    return ($names -join '、')
}
