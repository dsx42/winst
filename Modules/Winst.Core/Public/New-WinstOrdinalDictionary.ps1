#Requires -Version 5.1

function New-WinstOrdinalDictionary {
    <#
    .SYNOPSIS
        创建有序字典；默认区分大小写，文件名可按 Windows 语义忽略大小写。
    #>
    param([switch]$IgnoreCase)
    if ($IgnoreCase) {
        $map = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::OrdinalIgnoreCase)
        $map.PSObject.TypeNames.Insert(0, 'Winst.FileNameMap')
        return $map
    }
    return (New-Object 'System.Collections.Specialized.OrderedDictionary' ([StringComparer]::Ordinal))
}
