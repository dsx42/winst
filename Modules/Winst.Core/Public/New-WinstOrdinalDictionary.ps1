#Requires -Version 5.1

function New-WinstOrdinalDictionary {
    <#
    .SYNOPSIS
        新建区分大小写的有序字典。
    #>
    return (New-Object 'System.Collections.Specialized.OrderedDictionary' ([StringComparer]::Ordinal))
}
