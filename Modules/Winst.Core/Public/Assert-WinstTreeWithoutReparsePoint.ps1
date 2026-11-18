#Requires -Version 5.1

function Assert-WinstTreeWithoutReparsePoint {
    <#
    .SYNOPSIS
        校验路径链及整棵目录树；逐层枚举，发现重解析点即停止，绝不跟随其目标。
    #>
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$RequireFile)

    Assert-WinstSafeWritePath -Path $Path
    $root = Get-WinstFileSystemItem -Path $Path
    if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('目录树含有重解析点，已拒绝处理：{0}' -f $Path)
    }
    if ($root.PSIsContainer) {
        $hasFile = $false
        Get-WinstChildItem -Path $Path -Recurse -File | ForEach-Object { $hasFile = $true }
        if ($RequireFile -and -not $hasFile) { throw ('目录中没有可交付的文件：{0}' -f $Path) }
    }
}
