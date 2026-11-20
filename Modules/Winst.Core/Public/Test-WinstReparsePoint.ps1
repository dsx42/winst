#Requires -Version 5.1

function Test-WinstReparsePoint {
    <#
    .SYNOPSIS
        判断路径本身是否是重解析点（junction / 符号链接）。
    .OUTPUTS
        [bool]
    #>
    param([string]$Path)

    if (-not $Path) { return $false }
    $item = Get-WinstFileSystemItem -Path $Path -AllowMissing
    if ($null -eq $item) { return $false }
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}
