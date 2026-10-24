#Requires -Version 5.1

function Sort-WinstRowsByGroup {
    <#
    .SYNOPSIS
        列表排序：同一分组的条目聚拢（声明了分组的排在前面、按分组名排序）；未声明分组的排在最后。
    .DESCRIPTION
        菜单列表、CLI 列表与软件清单行共用同一套排序，保证「分组标题 + 同类聚拢」在两种界面下一致。
        只改变顺序，不改变条目数量与编号规则。

        -ByName：组内按 DisplayName 再排序（已装软件 / 已下载包 / 软件列表用；用户看到的是名称）。
        不传时组内只按 Id 排序（软件清单行用；行里未必有 DisplayName）。
    #>
    param($Rows, [switch]$ByName)

    $property = @{ Expression = { [bool]($_['Group']) }; Descending = $true },
                @{ Expression = { ([string]$_['Group']).ToLowerInvariant() } }
    if ($ByName) { $property += @{ Expression = { ([string]$_['DisplayName']).ToLowerInvariant() } } }
    $property += @{ Expression = { ([string]$_['Id']).ToLowerInvariant() } }

    return @($Rows | Sort-Object -Property $property)
}
