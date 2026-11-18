#Requires -Version 5.1

function Read-WinstSelectionFrom {
    <#
    .SYNOPSIS
        解析形如 `1 3 5` 的编号串（越界 / 非法返回空数组）。
    #>
    param([string]$Text, [int]$Count)

    return (Resolve-WinstSelectionText -Text $Text -Count $Count).Numbers
}
