#Requires -Version 5.1

function Format-WinstSizeText {
    <#
    .SYNOPSIS
        把字节数格式化成普通用户看得懂的大小文本（B / KB / MB / GB / TB，保留一位小数）。
    #>
    param([long]$Bytes)

    if ($Bytes -lt 0) { $Bytes = 0 }
    if ($Bytes -lt 1024) { return ('{0} B' -f $Bytes) }

    $units = @('KB', 'MB', 'GB', 'TB')
    $value = [double]$Bytes
    $index = -1
    while ($value -ge 1024 -and $index -lt ($units.Count - 1)) {
        $value = $value / 1024
        $index++
    }
    return ('{0:N1} {1}' -f $value, $units[$index])
}
