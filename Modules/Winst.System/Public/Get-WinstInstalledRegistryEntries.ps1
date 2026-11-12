#Requires -Version 5.1

function Get-WinstInstalledRegistryEntries {
    <#
    .SYNOPSIS
        显式枚举 HKLM / HKCU 的卸载记录；KeyPath 包含注册表视图。
    #>
    param([switch]$Force, [int]$TtlSeconds = 15, [hashtable]$Status = $null)

    $cached = Get-WinstState -Name WinstRegistryEntriesCache
    if (-not $Force -and $cached) {
        $age = ((Get-Date) - [datetime]$cached.At).TotalSeconds
        if ($age -ge 0 -and $age -lt $TtlSeconds) {
            if ($null -ne $Status) { $Status.Error = $cached.Error; $Status.Ok = -not [bool]$cached.Error }
            return @($cached.List)
        }
    }
    $list = New-Object 'System.Collections.Generic.List[object]'
    $queryErrors = @()
    $views = @('Registry32')
    if ([Environment]::Is64BitOperatingSystem) { $views += 'Registry64' }
    foreach ($view in $views) {
        foreach ($hive in @('LocalMachine','CurrentUser')) {
            if ($hive -eq 'CurrentUser' -and $view -eq 'Registry64') { continue }
            $base = $null
            $root = $null
            try {
                $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::$hive, [Microsoft.Win32.RegistryView]::$view)
                $root = $base.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')
                if ($null -eq $root) { continue }
                $hiveName = if ($hive -eq 'LocalMachine') { 'HKEY_LOCAL_MACHINE' } else { 'HKEY_CURRENT_USER' }
                foreach ($name in $root.GetSubKeyNames()) {
                    $path = '{0}::{1}\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{2}' -f $view, $hiveName, $name
                    try {
                        $row = Read-WinstUninstallRegistryEntry -KeyPath $path
                        if ($null -ne $row) { $list.Add($row) }
                    } catch { $queryErrors += ('{0}: {1}' -f $path, $_.Exception.Message) }
                }
            } catch { $queryErrors += ('{0}/{1}: {2}' -f $view, $hive, $_.Exception.Message) }
            finally {
                if ($root) { $root.Dispose() }
                if ($base) { $base.Dispose() }
            }
        }
    }
    $snapshot = @($list.ToArray())
    $queryError = $queryErrors -join '；'
    if ($null -ne $Status) { $Status.Error = $queryError; $Status.Ok = -not [bool]$queryError }
    $null = Set-WinstState WinstRegistryEntriesCache @{ At = (Get-Date); List = $snapshot; Error = $queryError }
    return $snapshot
}
