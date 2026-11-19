#Requires -Version 5.1

function Remove-WinstChildTree {
    <#
    .SYNOPSIS
        递归删除指定根目录下的条目，遇到重解析点只删除链接自身。
    #>
    param($Item, [string]$Base)

    if (-not (Test-WinstPathUnderRoot -Path $Item.FullName -Root $Base)) {
        throw ('清理条目不在指定目录下：{0}' -f $Item.FullName)
    }

    if ($Item.PSIsContainer) {
        # 进入目录前重读，防止枚举后被换成链接；删除原语也会在操作前重新取属性。
        $current = Get-WinstFileSystemItem -Path $Item.FullName
        if ($current.PSIsContainer -and ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
            foreach ($child in @(Get-WinstChildItem -Path $current.FullName)) {
                Remove-WinstChildTree -Item $child -Base $Base
            }
        }
    }
    Remove-WinstFileSystemItem -Path $Item.FullName
}
