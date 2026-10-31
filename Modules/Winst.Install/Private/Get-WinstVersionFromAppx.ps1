#Requires -Version 5.1

function Get-WinstVersionFromAppx {
    <#
    .SYNOPSIS
        detect.method = appx：从系统应用包记录读版本（顺带写回安装位置）。
    .DESCRIPTION
        名称规则应限定可比较版本的同一包家族，例如目标主系列的 framework 包。
        Windows App Runtime 不同主系列及 framework / Main / Singleton / DDLM 的内部版本体系
        可能不同，不能依赖版本比较识别产品归属。这里只在名称命中后选版本最高的包，
        不把其余包当作「旧版本」报给用户，以免误删运行时的组成部分。
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
    $query = @{}
    $package = Get-WinstAppxPackageBest -NameRule $pattern -Status $query
    $Result['QuerySucceeded'] = [bool]$query.Ok
    if (-not $query.Ok) { $Result.Note = [string]$query.Error }
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
