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
        [hashtable]$Config,
        [ref]$Source
    )

    $origin = 'default'
    $value = '%USERPROFILE%\winst'
    $optionRoot = Get-EntryString -Entry $Options -Key 'InstallRoot'
    if ($optionRoot) {
        $origin = 'param'
        $value = $optionRoot
    } elseif ($env:WINST_INSTALL_ROOT -and $env:WINST_INSTALL_ROOT.Trim()) {
        $origin = 'env'
        $value = $env:WINST_INSTALL_ROOT
    } else {
        $configured = Get-ConfigValue -Config $Config -Key 'installRoot'
        if ($configured) {
            $origin = 'config'
            $value = [string]$configured
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
    if (Test-WinstProtectedDirectory -Path $resolved) { throw ('软件安装位置是受保护目录：{0}' -f $resolved) }
    if ($Source) { $Source.Value = $origin }
    return $resolved
}
