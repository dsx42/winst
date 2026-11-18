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
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$RefreshSources,
        [switch]$ListOnly
    )

    $result = @{ Ok = $false; Error = ''; Warning = ''; Path = $Path; Exists = $false
                 Entries = @(); CommentLines = @(); BadLines = @(); Items = @(); Lookup = $null; Refresh = $null }

    $read = Read-WinstList -Path $Path
    if (-not $read.Ok) {
        $result.Error = $read.Error
        return $result
    }
    $result.Exists = $read.Exists
    $result.Entries = @($read.Entries)
    $result.CommentLines = @($read.CommentLines)
    $result.BadLines = @($read.BadLines)

    $ids = @(foreach ($entry in $read.Entries) { [string]$entry['Id'] })
    if ($RefreshSources -and @($read.Entries).Count -gt 0) {
        $refresh = Update-WinstDisplaySources -Context $Context -Ids $ids -Quiet
        $result.Refresh = $refresh
        Write-WinstRefreshErrors -Errors $refresh.Errors
    }

    $scope = @{}
    if ($ListOnly) { $scope.Ids = $ids }
    $lookup = Get-WinstListLookups -Context $Context @scope
    if (-not $lookup.Ok) {
        $result.Error = $lookup.Error
        return $result
    }
    $result.Lookup = $lookup
    $result.Warning = [string]$lookup.Warning

    $result.Items = @(foreach ($entry in @($read.Entries)) {
        $id = [string]$entry['Id']
        if (-not $id) { continue }
        (New-WinstListItem -Context $Context -Id $id -PinnedVersion ([string]$entry['Version']) -Lookup $lookup)
    })
    $result.Ok = $true
    return $result
}
