#Requires -Version 5.1

function Resolve-InstallRoot {
    <#
    .SYNOPSIS
        解析安装根目录：--install-root > WINST_INSTALL_ROOT > config.json > 默认值。
    .DESCRIPTION
        软件安装根目录只允许本地路径；环境变量展开、相对路径归一化后同样拒绝 UNC 与网络映射盘。
    #>
    param(
        [string]$DataRoot,
        [hashtable]$Options,
        [hashtable]$Config
    )

    $value = '%USERPROFILE%\winst'
    if ($Options -and $Options.InstallRoot) {
        $value = [string]$Options.InstallRoot
    } elseif ($env:WINST_INSTALL_ROOT -and $env:WINST_INSTALL_ROOT.Trim()) {
        $value = $env:WINST_INSTALL_ROOT
    } else {
        $configPath = Join-WinstPath $DataRoot 'config.json'
        if (Test-Path -LiteralPath $configPath -PathType Leaf) {
            $configured = Get-ConfigValue -Config $Config -Key 'installRoot'
            if ($configured) { $value = [string]$configured }
        }
    }

    $resolved = Expand-WinstPath -Path $value -Base $DataRoot
    $plainPath = ConvertTo-WinstPlainDevicePath -Path $resolved
    if ($plainPath.StartsWith('\\')) {
        throw '软件安装位置只允许本地路径，不支持 UNC 路径；只有安装包位置（pkgDir）可以使用网络共享。'
    }
    if ($plainPath -match '^([A-Za-z]):') {
        $drive = New-Object IO.DriveInfo($Matches[1])
        if ($drive.DriveType -eq [IO.DriveType]::Network) {
            throw '软件安装位置只允许本地路径，不支持网络映射盘；网络共享只能用于安装包位置（pkgDir）。'
        }
    }
    return $resolved
}
