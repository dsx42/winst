#Requires -Version 5.1

function Assert-WinstTreeWithoutReparsePoint {
    <#
    .SYNOPSIS
        复制前筛查路径链和树内重解析点，防止递归复制进入链接目标。
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-WinstSafeWritePath -Path $Path
    $root = Get-WinstFileSystemItem -Path $Path
    if (-not $root.PSIsContainer) { return }
    $link = Get-ChildItem -LiteralPath $root.ExtendedPath -Recurse -Force -Attributes ReparsePoint -ErrorAction Stop | Select-Object -First 1
    if ($link) { throw ('目录树含有重解析点，已拒绝处理：' + $link.FullName) }
}
