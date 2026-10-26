#Requires -Version 5.1

function Get-WinstVersionFromAppx {
    <#
    .SYNOPSIS
        detect.method = appx：从系统应用包记录读版本（顺带写回安装位置）。
    .DESCRIPTION
        同一家族常常同时装着多个包（Windows App Runtime 的 framework / Main / Singleton / DDLM），
        它们的版本号各不相同、而且都是运行时的一部分（DDLM 按版本命名是设计要求）。
        因此这里只取**版本最高的那个包**作为本机版本，**不**把其余包当作「旧版本」报给用户——
        那会把运行时的组成部分说成待清理的旧版本，用户照着删掉会弄坏运行时。
        安装 / 更新后由 Remove-WinstAppxOutdatedPackages 负责清理真正该清的残留包。
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
    try { $location = ([string]$package.InstallLocation).Trim() } catch { $location = '' }
    if ($location) { $Result['Location'] = $location }

    $detail = ('应用包: {0}' -f $fullName)
    if ($location) { $detail = ('应用包: {0}（位置: {1}）' -f $fullName, $location) }
    $raw = ''
    try { $raw = [string]$package.Version } catch { $raw = '' }
    Set-WinstDetectedVersionFromRaw -Result $Result -Raw $raw -Kind $Kind -Between $Between -Detail $detail
}
