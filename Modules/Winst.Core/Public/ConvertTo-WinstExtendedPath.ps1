#Requires -Version 5.1

function ConvertTo-WinstExtendedPath {
    <#
    .SYNOPSIS
        将本地或 UNC 文件路径归一化为扩展长度绝对路径，仅供文件系统操作使用。
    .DESCRIPTION
        路径比较、台账和保留规则使用普通路径；设备命名空间只接受盘符及 UNC 形式。
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)

    $plain = ConvertTo-WinstPlainDevicePath -Path $Path
    if ($plain.StartsWith('\\?\', [StringComparison]::Ordinal) -or
        $plain.StartsWith('\\.\', [StringComparison]::Ordinal) -or
        $plain.StartsWith('\??\', [StringComparison]::Ordinal)) {
        throw ('不支持的设备路径：{0}' -f $Path)
    }
    # 扩展路径不折叠尾点、尾空格；先拒绝这些名字，避免普通路径表示指向另一个条目。
    foreach ($segment in ($plain -split '[\\/]')) {
        if (-not $segment -or $segment -eq '.' -or $segment -eq '..') { continue }
        if ($segment.EndsWith('.') -or $segment.EndsWith(' ')) {
            throw ('路径含有尾点或尾空格名称：{0}' -f $Path)
        }
    }
    $full = [IO.Path]::GetFullPath($plain)
    $root = [IO.Path]::GetPathRoot($full)
    foreach ($segment in ($full.Substring($root.Length) -split '\\')) {
        if (-not $segment) { continue }
        if ($segment.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
            (Test-WinstReservedDeviceName -Name $segment)) {
            throw ('路径含有非法名称或保留设备名：{0}' -f $Path)
        }
    }
    if ($full -match '^[A-Za-z]:\\') { return ('\\?\' + $full) }
    if ($full -match '^\\\\[^\\]+\\[^\\]+') { return ('\\?\UNC\' + $full.Substring(2)) }
    throw ('无法转换为本地或 UNC 绝对路径：{0}' -f $Path)
}
