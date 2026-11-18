#Requires -Version 5.1

function Get-WinstSystemItemOwners {
    param($Context, $State, [string]$ExceptId, [switch]$Declarations)

    $owners = @{ Env = @{}; Paths = @{}; Shortcuts = @{} }
    foreach ($id in $State.Installed.Keys) {
        if ($id -ceq $ExceptId) { continue }
        $entry = $State.Installed[$id]
        foreach ($link in @(Get-EntryArray -Entry $entry -Key 'appliedShortcuts')) {
            $owners.Shortcuts[[string]$link] = $true
        }
        if (-not $Declarations) { continue }
        $declared = Get-WinstInstalledDeclaredItems -Context $Context -Id $id -Entry $entry
        $stamp = [datetime]::MinValue
        [void][datetime]::TryParse((Get-EntryString -Entry $entry -Key 'installedAt'), [ref]$stamp)
        foreach ($item in $declared.Env) {
            $key = $item.scope + '|' + $item.name
            if ($owners.Env.ContainsKey($key) -and $owners.Env[$key].Stamp -ge $stamp) { continue }
            $errorText = ''
            if ($null -eq $item.value) { $errorText = ('软件源里没有「{0}」，无法确认它需要的值' -f $id) }
            $owners.Env[$key] = @{ Stamp = $stamp; FromId = $id; Value = [string]$item.value; Error = $errorText }
        }
        foreach ($item in $declared.PathItems) {
            $key = $item.scope + '|' + $item.path
            if (-not $owners.Paths.ContainsKey($key)) { $owners.Paths[$key] = $id }
        }
    }
    return $owners
}
