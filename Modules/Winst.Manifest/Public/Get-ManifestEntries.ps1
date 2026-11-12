#Requires -Version 5.1

function Get-ManifestEntries {
    <#
    .SYNOPSIS
        从清单对象中取出条目数组：catalog 包裹 / 顶层数组 / 顶层单条目三种形态归一化。
    #>
    param($Manifest)

    $result = New-Object 'System.Collections.Generic.List[object]'
    $entries = $null
    if ($Manifest -is [System.Array]) {
        $entries = $Manifest
    } elseif ($Manifest -is [System.Management.Automation.PSCustomObject] -or $Manifest -is [System.Collections.IDictionary]) {
        $hasApps = if ($Manifest -is [System.Collections.IDictionary]) { $Manifest.Contains('apps') } else { $null -ne $Manifest.PSObject.Properties['apps'] }
        $apps = $null
        if ($hasApps) { $apps = $Manifest.apps }
        if ($apps -is [System.Array]) { $entries = $apps }
        elseif (-not $hasApps -and (Get-EntryString -Entry $Manifest -Key 'id')) { $entries = @($Manifest) }
    }
    if ($null -eq $entries) { throw '清单必须是条目数组、含 id 的单条目或含 apps 数组的对象' }
    foreach ($item in $entries) {
        if (($item -isnot [System.Management.Automation.PSCustomObject] -and $item -isnot [System.Collections.IDictionary]) -or -not (Get-EntryString -Entry $item -Key 'id')) { throw '清单数组中的每项必须是含 id 的条目对象' }
        $result.Add($item)
    }
    return @($result.ToArray())
}
