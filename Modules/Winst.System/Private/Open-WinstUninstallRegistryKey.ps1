#Requires -Version 5.1

function Open-WinstUninstallRegistryKey {
    <#
    .SYNOPSIS
        按带视图的卸载键身份打开记录；兼容台账中的注册表提供程序路径。
    #>
    param([string]$KeyPath, [switch]$Writable, [switch]$Parent)

    $path = $KeyPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''
    $view = if ([Environment]::Is64BitOperatingSystem) { 'Registry64' } else { 'Registry32' }
    if ($path -match '^(Registry32|Registry64)::(.+)$') { $view = $Matches[1]; $path = $Matches[2] }
    $path = $path -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\' -replace '^HKCU:\\', 'HKEY_CURRENT_USER\'
    if ($path -notmatch '^(HKEY_LOCAL_MACHINE|HKEY_CURRENT_USER)\\SOFTWARE\\(WOW6432Node\\)?Microsoft\\Windows\\CurrentVersion\\Uninstall\\([^\\]+)$') {
        throw ('不是系统安装记录里的键，已拒绝操作: {0}' -f $KeyPath)
    }
    $hive = if ($Matches[1] -eq 'HKEY_LOCAL_MACHINE') { [Microsoft.Win32.RegistryHive]::LocalMachine } else { [Microsoft.Win32.RegistryHive]::CurrentUser }
    if ($Matches[2]) { $view = 'Registry32' }
    $name = $Matches[3]
    if ($name -in @('.','..') -or $name.EndsWith('.')) { throw ('卸载键名不安全: {0}' -f $KeyPath) }
    $subKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    if (-not $Parent) { $subKey += '\' + $name }
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::$view)
    try { return $base.OpenSubKey($subKey, [bool]$Writable) } finally { $base.Dispose() }
}
