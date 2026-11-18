#Requires -Version 5.1

function Get-WinstFileSystemItem {
    <#
    .SYNOPSIS
        使用扩展路径读取文件属性，返回普通绝对路径及条目名称、属性和目录标记。
    .DESCRIPTION
        AllowMissing 仅允许文件或父目录不存在；访问被拒绝及其他读取错误仍抛出。
        返回独立元数据对象，不让设备路径前缀进入路径比较和 keep 匹配。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path, [switch]$AllowMissing)

    $extended = ConvertTo-WinstExtendedPath -Path $Path
    $full = ConvertTo-WinstPlainDevicePath -Path $extended
    try { $attributes = [IO.File]::GetAttributes($extended) }
    catch {
        $errorCode = $_.Exception.GetBaseException().HResult -band 0xFFFF
        if ($AllowMissing -and $errorCode -in @(2, 3)) { return $null }
        throw
    }
    $root = [IO.Path]::GetPathRoot($full)
    if ($full -ine $root) { $full = $full.TrimEnd('\') }
    return [pscustomobject]@{
        ExtendedPath = $extended
        FullName = $full
        Name = [IO.Path]::GetFileName($full.TrimEnd('\'))
        Attributes = $attributes
        PSIsContainer = (($attributes -band [IO.FileAttributes]::Directory) -ne 0)
    }
}
