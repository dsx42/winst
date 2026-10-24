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
    try { $Item = Get-Item -LiteralPath $Item.FullName -Force -ErrorAction Stop } catch { return }

    $relative = ''
    try { $relative = $Item.FullName.Substring($Base.Length).TrimStart('\') } catch { $relative = $Item.Name }
    if (Test-WinstKeepMatch -RelativePath $relative -Name $Item.Name -Keep $Keep) { return }

    # 重解析点（junction / 符号链接）只删链接本身：Remove-Item -Recurse 会跟随链接把目标目录里的内容删掉
    if (Test-WinstReparsePoint -Path $Item.FullName) {
        try {
            if ($Item.PSIsContainer) { [IO.Directory]::Delete($Item.FullName, $false) }
            else { [IO.File]::Delete($Item.FullName) }
        } catch { }
        return
    }

    if ($Item.PSIsContainer) {
        foreach ($child in @(Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue)) {
            Remove-WinstItemWithKeep -Item $child -Base $Base -Keep $Keep
        }
        $remain = @(Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue)
        if ($remain.Count -eq 0) {
            try { [IO.Directory]::Delete($Item.FullName, $false) } catch { }
        }
    } else {
        Remove-Item -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue
    }
}
