#Requires -Version 5.1

function Test-WinstReparsePoint {
    <#
    .SYNOPSIS
        判断路径本身是否是重解析点（junction / 符号链接）。
    .DESCRIPTION
        `Remove-Item -Recurse` 会**跟随**目录 junction 删掉链接目标里的内容：安装目录里若被放了
        junction 指向用户数据目录，递归清理会连带清空目标。删除 / 合并前逐项跳过重解析点。
    .OUTPUTS
        [bool]
    #>
    param([string]$Path)

    if (-not $Path) { return $false }
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if (-not $item) { return $false }
        return (([int]$item.Attributes -band [int][IO.FileAttributes]::ReparsePoint) -ne 0)
    } catch {
        return $false
    }
}
