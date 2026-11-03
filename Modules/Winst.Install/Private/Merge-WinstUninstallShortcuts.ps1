#Requires -Version 5.1

function Merge-WinstUninstallShortcuts {
    <#
    .SYNOPSIS
        快捷方式：只回收台账登记的实际写入路径。
    .OUTPUTS
        [string[]]
    #>
    param($Entry)

    $shortcuts = @()
    $shortcutSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedShortcuts')) {
        $text = ([string]$item).Trim()
        if (-not $text -or $shortcutSeen.ContainsKey($text)) { continue }
        $shortcutSeen[$text] = $true
        $shortcuts += $text
    }
    return $shortcuts
}
