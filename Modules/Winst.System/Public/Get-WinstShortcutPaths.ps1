#Requires -Version 5.1

function Get-WinstShortcutPaths {
    <#
    .SYNOPSIS
        按条目的 shortcuts 声明推导 .lnk 完整路径列表。
    .OUTPUTS
        @( <桌面 / 开始菜单 .lnk 完整路径> )
    #>
    param($Plan)

    $paths = @()
    $shortcuts = Get-EntryValue -Entry $Plan -Key 'shortcuts' -Default $null
    $desktopOn = Get-EntryBool -Entry $shortcuts -Key 'desktop'
    $startMenuOn = Get-EntryBool -Entry $shortcuts -Key 'startMenu'
    if (-not $desktopOn -and -not $startMenuOn) { return @() }

    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = Get-EntryString -Entry $Plan -Key 'id' }
    if (-not $displayName) { return @() }
    $fileName = ConvertTo-ShortcutName -Name $displayName

    if ($desktopOn) {
        $desktopDir = ''
        try { $desktopDir = [Environment]::GetFolderPath('Desktop') } catch { $desktopDir = '' }
        if ($desktopDir) { $paths += (Join-WinstPath $desktopDir $fileName) }
    }
    if ($startMenuOn -and $env:APPDATA) {
        $paths += (Join-WinstPath $env:APPDATA ('Microsoft\Windows\Start Menu\Programs\' + $fileName))
    }
    return @($paths)
}
