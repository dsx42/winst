#Requires -Version 5.1

function Resolve-WinstActualInstallDir {
    <#
    .SYNOPSIS
        安装版软件的实际安装目录：以系统安装记录为准；记录里拿不到路径时退回预期目录（仅当它确实存在）。
    .DESCRIPTION
        安装器可以装到任意位置（忽略 installRoot\id，或用户改了安装目录），因此安装记录的 installDir 不能用
        installRoot\id 假设，必须探测。
    .OUTPUTS
        @{ Dir; FromRegistry } —— FromRegistry 表示目录取自系统安装记录（而不是 winst 的预期目录）
    #>
    param($Plan, [string]$AssumedDir = '')

    $result = @{ Dir = ''; FromRegistry = $false }

    # 应用包（msixbundle）安装：安装位置取系统应用包记录里的 InstallLocation（这类软件不在注册表卸载项里）
    $detect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
    if ((Get-EntryString -Entry $detect -Key 'method').Trim().ToLowerInvariant() -eq 'appx') {
        $package = Get-WinstAppxPackageBest -NameRule (Get-EntryString -Entry $detect -Key 'name')
        if ($package) {
            $location = ''
            try { $location = ([string]$package.InstallLocation).Trim() } catch { $location = '' }
            if ($location) {
                $result.Dir = $location
                $result.FromRegistry = $true
                return $result
            }
        }
    }

    $hit = Get-WinstRegistryEntryForPlan -Plan $Plan -InstallDir $AssumedDir
    if ($hit) {
        $dir = Get-WinstRegistryEntryInstallDir -Entry $hit
        if ($dir) {
            $result.Dir = $dir
            $result.FromRegistry = $true
            return $result
        }
    }
    if ($AssumedDir -and (Test-Path -LiteralPath $AssumedDir -PathType Container)) {
        $result.Dir = $AssumedDir
    }
    return $result
}
