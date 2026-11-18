#Requires -Version 5.1

function Get-WinstPlanShortcutDirectories {
    <#
    .SYNOPSIS
        取得本机桌面和开始菜单程序目录，供安装计划显示快捷方式位置。
    #>
    $desktopDir = ''
    try { $desktopDir = [Environment]::GetFolderPath('Desktop') } catch { }
    $startMenuDir = ''
    if ($env:APPDATA) { $startMenuDir = Join-WinstPath $env:APPDATA 'Microsoft\Windows\Start Menu\Programs' }
    return @{ DesktopDir = $desktopDir; StartMenuDir = $startMenuDir }
}
