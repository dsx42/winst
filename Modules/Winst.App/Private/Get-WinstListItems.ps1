#Requires -Version 5.1

function Get-WinstListItems {
    <#
    .SYNOPSIS
        读取清单文件并产出条目视图数组（含 Lookup，便于调用方复用同一份数据）。
    .OUTPUTS
        @{ Ok; Error; Warning; Path; Exists; Entries; CommentLines; BadLines; Items; Lookup }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $result = @{ Ok = $false; Error = ''; Warning = ''; Path = $Path; Exists = $false
                 Entries = @(); CommentLines = @(); BadLines = @(); Items = @(); Lookup = $null }

    $read = Read-WinstList -Path $Path
    if (-not $read.Ok) {
        $result.Error = $read.Error
        return $result
    }
    $result.Exists = $read.Exists
    $result.Entries = @($read.Entries)
    $result.CommentLines = @($read.CommentLines)
    $result.BadLines = @($read.BadLines)

    $lookup = Get-WinstListLookups -Context $Context
    if (-not $lookup.Ok) {
        $result.Error = $lookup.Error
        return $result
    }
    $result.Lookup = $lookup
    $result.Warning = [string]$lookup.Warning

    $items = @()
    foreach ($entry in @($read.Entries)) {
        $id = [string]$entry['Id']
        if (-not $id) { continue }
        $items += (New-WinstListItem -Context $Context -Id $id -PinnedVersion ([string]$entry['Version']) -Lookup $lookup)
    }
    $result.Items = @($items)
    $result.Ok = $true
    return $result
}
