#Requires -Version 5.1

function Remove-WinstItemWithKeep {
    <#
    .SYNOPSIS
        递归删除安装目录内的条目，命中 keep 的文件 / 目录整棵保留。
    #>
    param($Item, [string]$Base, $Rules)

    if (-not (Test-WinstPathUnderRoot -Path $Item.FullName -Root $Base)) {
        throw ('清理条目不在指定目录下：{0}' -f $Item.FullName)
    }
    if ($Rules.Count -gt 0) {
        $relative = $Item.FullName.Substring($Base.Length).TrimStart('\')
        if (Test-WinstKeepMatch -RelativePath $relative -Name $Item.Name -Rules $Rules) { return $true }
    }

    if ($Item.PSIsContainer) {
        # 进入目录前重读，防止枚举后被换成链接；删除原语也会在操作前重新取属性。
        $current = Get-WinstFileSystemItem -Path $Item.FullName
        if ($current.PSIsContainer -and ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
            $retained = $false
            foreach ($child in @(Get-WinstChildItem -Path $current.FullName)) {
                if (Remove-WinstItemWithKeep -Item $child -Base $Base -Rules $Rules) { $retained = $true }
            }
            if ($retained) { return $true }
        }
    }
    Remove-WinstFileSystemItem -Path $Item.FullName
    return $false
}
