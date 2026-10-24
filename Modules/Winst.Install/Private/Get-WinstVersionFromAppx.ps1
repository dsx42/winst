#Requires -Version 5.1

function Get-WinstVersionFromAppx {
    <#
    .SYNOPSIS
        detect.method = appx：从系统应用包记录读版本（顺带写回安装位置）。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        $Detect,
        [string]$InstallDir = '',
        [string]$Kind = '',
        $Between = @(),
        [hashtable]$Result
    )

    # 应用包（MSIX / AppX）：Windows App Runtime、Windows Terminal 这类软件不在注册表卸载项里，
    # 版本与安装位置都从系统的应用包记录里读
    $pattern = Get-EntryString -Entry $Detect -Key 'name'
    if (-not $pattern) { return }
    $package = Get-WinstAppxPackageBest -NameRule $pattern
    if (-not $package) { return }

    $Result.Found = $true
    $fullName = ''
    try { $fullName = [string]$package.PackageFullName } catch { $fullName = '' }
    $location = ''
    try { $location = [string]$package.InstallLocation } catch { $location = '' }
    if ($location) { $Result['Location'] = $location }

    $detail = ('应用包: {0}' -f $fullName)
    if ($location) { $detail = ('应用包: {0}（位置: {1}）' -f $fullName, $location) }
    $raw = ''
    try { $raw = [string]$package.Version } catch { $raw = '' }
    Set-WinstDetectedVersionFromRaw -Result $Result -Raw $raw -Kind $Kind -Between $Between -Detail $detail
}
