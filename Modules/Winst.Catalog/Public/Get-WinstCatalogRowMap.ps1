#Requires -Version 5.1

function Get-WinstCatalogRowMap {
    <#
    .SYNOPSIS
        把软件清单视图按区分大小写的 id 建索引，供各 Overview 与清单流程共用。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $map = New-WinstOrdinalDictionary
    foreach ($row in @(Get-WinstSearchCatalog -Context $Context)) {
        $id = [string]$row['Id']
        if ($id -and -not $map.Contains($id)) { $map[$id] = $row }
    }
    return $map
}
