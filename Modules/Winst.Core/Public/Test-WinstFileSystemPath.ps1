#Requires -Version 5.1

function Test-WinstFileSystemPath {
    <#
    .SYNOPSIS
        检查长路径条目是否存在及其类型；无法读取属性时明确报错。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet('Any', 'Leaf', 'Container')][string]$PathType = 'Any'
    )

    $item = Get-WinstFileSystemItem -Path $Path -AllowMissing
    if ($null -eq $item) { return $false }
    if ($PathType -eq 'Container') { return [bool]$item.PSIsContainer }
    if ($PathType -eq 'Leaf') { return (-not $item.PSIsContainer) }
    return $true
}
