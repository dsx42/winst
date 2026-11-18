#Requires -Version 5.1

function Get-WinstCatalogRowMap {
    <#
    .SYNOPSIS
        把软件清单视图按区分大小写的 id 建索引，供各 Overview 与清单流程共用。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context, [string[]]$Ids)

    $map = New-WinstOrdinalDictionary
    $scope = @{}
    if ($PSBoundParameters.ContainsKey('Ids')) { $scope.Ids = $Ids }
    foreach ($row in @(Get-WinstSearchCatalog -Context $Context @scope)) {
        $id = [string]$row['Id']
        if ($id -and -not $map.Contains($id)) { $map[$id] = $row }
    }
    return $map
}
