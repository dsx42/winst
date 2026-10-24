#Requires -Version 5.1

function Get-WinstInstallerExpectedDir {
    <#
    .SYNOPSIS
        安装版软件（installer）的预期安装位置：从安装命令里解析，解析不出时返回空串。
    .DESCRIPTION
        安装版软件的安装位置由安装程序自己决定，只有安装命令里确实写明了路径才值得展示：
        ① 主包是 .msi 时，winst 会给 msiexec 传 TARGETDIR=<软件安装目录>，预期位置即该目录；
        ② 安装参数里写明了安装路径——NSIS 的 /D=（必须是最后一个参数）、Inno Setup 的 /DIR=、
           MSI 属性 TARGETDIR / INSTALLDIR / INSTALLLOCATION 等、以及 --install-dir= 形式。
    #>
    param(
        $Plan,
        [string]$InstallArgs = '',
        [string]$InstallDir = ''
    )

    # .msi：winst 自己会在安装命令里补 TARGETDIR=<软件安装目录>（见 Invoke-WinstAppInstall）
    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -gt 0) {
        $name = Get-EntryString -Entry $files[0] -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url (Get-EntryString -Entry $files[0] -Key 'url') }
        if ($name -and $name.ToLowerInvariant().EndsWith('.msi')) { return $InstallDir }
    }

    if (-not $InstallArgs) { return '' }
    $valuePattern = '("(?<dir>[^"]+)"|''(?<dir>[^'']+)''|(?<dir>[^\s"'']+))'
    $patterns = @(
        '(?i)(?:^|\s)/D\s*=\s*(?<dir>.+)$',
        ('(?i)(?:^|\s)/(?:DIR|DIRECTORY|INSTALLDIR|INSTALLLOCATION)\s*=\s*' + $valuePattern),
        ('(?i)(?:^|\s)(?:TARGETDIR|INSTALLDIR|INSTALLLOCATION|INSTALLPATH|INSTALL_LOCATION|APPLICATIONFOLDER|APPDIR)\s*=\s*' + $valuePattern),
        ('(?i)(?:^|\s)--(?:install-?dir|destdir|destination)\s*(?:=|\s)\s*' + $valuePattern)
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($InstallArgs, $pattern)
        if (-not $match.Success) { continue }
        $dir = $match.Groups['dir'].Value.Trim().Trim('"').Trim("'")
        if ($dir) { return $dir }
    }
    return ''
}
