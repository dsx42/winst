#Requires -Version 5.1

function Format-LinkSpec {
    <#
    .SYNOPSIS
        把 page 源的 link 条件格式化为可读文本（用于报错信息）。
    #>
    param($Spec)

    $parts = @()
    $className = Get-EntryString -Entry $Spec -Key 'class'
    if ($className) { $parts += ('按钮样式 {0}' -f $className) }
    $id = Get-EntryString -Entry $Spec -Key 'id'
    if ($id) { $parts += ('按钮编号 {0}' -f $id) }
    $text = Get-EntryString -Entry $Spec -Key 'text'
    if ($text) { $parts += ('按钮文字包含 "{0}"' -f $text) }
    $href = Get-EntryString -Entry $Spec -Key 'href'
    if ($href) { $parts += ('按钮地址符合 "{0}"' -f $href) }
    if ($parts.Count -eq 0) { return '未限定任何条件' }
    return ($parts -join '，')
}
