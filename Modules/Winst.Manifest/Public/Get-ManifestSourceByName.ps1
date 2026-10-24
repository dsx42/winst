#Requires -Version 5.1

function Get-ManifestSourceByName {
    <#
    .SYNOPSIS
        按名称（不区分大小写）在全部软件源中查找，未命中返回 $null。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Name
    )

    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        if ([string]$source['name'] -ieq $Name) { return $source }
    }
    return $null
}
