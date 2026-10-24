#Requires -Version 5.1

function Get-WinstInstallScope {
    <#
    .SYNOPSIS
        按安装目录判定 env / PATH 的写入作用域。
    .DESCRIPTION
        安装目录位于用户配置文件目录 %USERPROFILE% 之下（前缀匹配、不区分大小写、允许相等）→ User；
        其它位置 → Machine。判定只与安装目录有关，与环境变量值无关。
    #>
    param([string]$InstallDir)

    $profileDir = ''
    try { $profileDir = [Environment]::GetFolderPath('UserProfile') } catch { $profileDir = '' }
    if (-not $profileDir -and $env:USERPROFILE) { $profileDir = $env:USERPROFILE }
    if (-not $InstallDir -or -not $profileDir) { return 'User' }

    $normalizedDir = ([string]$InstallDir).TrimEnd('\')
    $normalizedProfile = $profileDir.TrimEnd('\')
    if ($normalizedDir -ieq $normalizedProfile) { return 'User' }
    if ($normalizedDir.StartsWith($normalizedProfile + '\', [StringComparison]::OrdinalIgnoreCase)) { return 'User' }
    return 'Machine'
}
