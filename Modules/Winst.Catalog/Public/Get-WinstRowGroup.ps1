#Requires -Version 5.1

function Get-WinstRowGroup {
    <#
    .SYNOPSIS
        取软件清单行的分组名；未声明时返回空串。
    .DESCRIPTION
        同一 id 在多个软件源里都有定义时，按来源顺序取第一个非空的 group——分组是展示属性，
        各来源写的是同一个分组名，不参与版本比较。
    #>
    param($Row)

    if ($null -eq $Row) { return '' }
    foreach ($entry in @($Row['Sources'])) {
        $group = (Get-EntryString -Entry $entry['Plan'] -Key 'group').Trim()
        if ($group) { return $group }
    }
    return ''
}
