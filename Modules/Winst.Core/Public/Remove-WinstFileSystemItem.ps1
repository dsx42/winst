#Requires -Version 5.1

function Remove-WinstFileSystemItem {
    <#
    .SYNOPSIS
        使用扩展路径删除单个文件、空目录或链接；目录不递归，链接只删除自身。
    .DESCRIPTION
        调用方负责允许根目录及路径链安全检查。普通只读文件和目录删除前清除只读属性。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    $item = Get-WinstFileSystemItem -Path $Path
    $extended = ConvertTo-WinstExtendedPath -Path $item.FullName
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0 -and
        ($item.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
        [IO.File]::SetAttributes($extended, ($item.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)))
    }
    if ($item.PSIsContainer) {
        [IO.Directory]::Delete($extended, $false)
    } else {
        [IO.File]::Delete($extended)
    }
}

