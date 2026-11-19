#Requires -Version 5.1

function Remove-WinstDirectoryTree {
    <#
    .SYNOPSIS
        检查删除目标及祖先路径后，用一条命令删除整个目录。
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-WinstSafeWritePath -Path $Path -Directory
    $item = Get-WinstFileSystemItem -Path $Path
    if (-not $item.PSIsContainer) { throw ('删除目标不是目录：' + $Path) }
    Remove-Item -LiteralPath ('FileSystem::' + $item.ExtendedPath) -Recurse -Force -ErrorAction Stop
}
