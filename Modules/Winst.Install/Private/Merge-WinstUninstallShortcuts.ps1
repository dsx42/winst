#Requires -Version 5.1

function Merge-WinstUninstallShortcuts {
    <#
    .SYNOPSIS
        快捷方式：已登记的实际路径 + 软件源按固定命名规则推导的路径（老记录没有登记时兜底）。
    .OUTPUTS
        [string[]]
    #>
    param($Entry, $ManifestPlan)

    $shortcuts = @()
    $shortcutSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedShortcuts')) {
        $text = ([string]$item).Trim()
        if (-not $text -or $shortcutSeen.ContainsKey($text)) { continue }
        $shortcutSeen[$text] = $true
        $shortcuts += $text
    }
    if ($ManifestPlan) {
        foreach ($link in @(Get-WinstShortcutPaths -Plan $ManifestPlan)) {
            $text = ([string]$link).Trim()
            if (-not $text -or $shortcutSeen.ContainsKey($text)) { continue }
            $shortcutSeen[$text] = $true
            $shortcuts += $text
        }
    }
    return $shortcuts
}
