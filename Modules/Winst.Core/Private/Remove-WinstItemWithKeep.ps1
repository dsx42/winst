#Requires -Version 5.1

function Remove-WinstItemWithKeep {
    <#
    .SYNOPSIS
        递归删除安装目录内的条目，命中 keep 的文件 / 目录整棵保留。
    #>
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$Base,
        [string[]]$Keep = @()
    )

    # 调用方枚举后到真正处理之间，条目可能被换成重解析点；处理前重新读取属性。
    $Item = Get-WinstFileSystemItem -Path $Item.FullName

    $relative = ''
    $baseFull = [IO.Path]::GetFullPath((ConvertTo-WinstPlainDevicePath -Path $Base)).TrimEnd('\')
    if (-not (Test-WinstPathUnderRoot -Path $Item.FullName -Root $baseFull)) {
        throw ('清理条目不在指定目录下：{0}' -f $Item.FullName)
    }
    $relative = $Item.FullName.Substring($baseFull.Length).TrimStart('\')
    if (Test-WinstKeepMatch -RelativePath $relative -Name $Item.Name -Keep $Keep) { return }

    # 重解析点（junction / 符号链接）只删链接本身：Remove-Item -Recurse 会跟随链接把目标目录里的内容删掉
    if (Test-WinstReparsePoint -Path $Item.FullName) {
        Remove-WinstFileSystemItem -Path $Item.FullName
        return
    }

    if ($Item.PSIsContainer) {
        foreach ($child in @(Get-WinstChildItem -Path $Item.FullName)) {
            Remove-WinstItemWithKeep -Item $child -Base $Base -Keep $Keep
        }
        $remain = @(Get-WinstChildItem -Path $Item.FullName)
        if ($remain.Count -eq 0) {
            Remove-WinstFileSystemItem -Path $Item.FullName
        }
    } else {
        Remove-WinstFileSystemItem -Path $Item.FullName
    }
}
