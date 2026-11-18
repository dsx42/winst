#Requires -Version 5.1

function Update-WinstEnvironmentSnapshot {
    param($Before, $After)

    $snapshot = Get-WinstState -Name WinstEnvironmentCache
    if ($null -eq $snapshot) { return }
    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $snapshot.Items) {
        if ($Before -notcontains $item) { $items.Add($item) }
    }
    foreach ($item in $After) { if ($null -ne $item) { $items.Add($item) } }
    $snapshot.Items = $items.ToArray()
}
