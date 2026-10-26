#Requires -Version 5.1

function Test-WinstUninstallerUsable {
    <#
    .SYNOPSIS
        判断一条系统安装记录里的卸载程序现在还能不能跑起来（只做解析与存在性检查，不执行）。
    .DESCRIPTION
        同一个软件常常有两层记录，外面那层不一定还能用：

        - 外层 burn 引导包：卸载命令指向 `%ProgramData%\Package Cache\{...}\xxx.exe`，
          磁盘清理 / 手动清缓存后这个文件就没了，记录却还留在注册表里；
        - 内层 MSI：`MsiExec.exe /X{GUID}`，安装缓存放在 `C:\Windows\Installer`，
          不受前面的清理影响，通常仍然可卸载。

        因此「哪条记录能用来卸掉这个版本」必须按**现在是否可用**判断，不能只看它是不是外层引导包。
    .OUTPUTS
        [bool]
    #>
    param($Entry)

    if ($null -eq $Entry) { return $false }
    $commandLine = ''
    if ($Entry -is [System.Collections.IDictionary]) {
        if ($Entry.Contains('UninstallString')) { $commandLine = [string]$Entry['UninstallString'] }
    } else {
        $prop = $Entry.PSObject.Properties['UninstallString']
        if ($prop -and $null -ne $prop.Value) { $commandLine = [string]$prop.Value }
    }
    if (-not $commandLine.Trim()) { return $false }

    $resolved = Resolve-WinstUninstallerCommand -CommandLine $commandLine
    return [bool]$resolved.Ok
}
