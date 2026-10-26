#Requires -Version 5.1

function Test-WinstRegistryEntryIsMsi {
    <#
    .SYNOPSIS
        判断一条系统安装记录是不是「内层 MSI」（卸载命令是 MsiExec）。
    .DESCRIPTION
        同一个安装器常留下两层记录：外层 burn 引导包（自带 exe 卸载器，DisplayVersion 是产品版本）
        与内层 MSI（MsiExec 卸载，DisplayVersion 是 MSI 内部编号如 80.x）。
        两层记录的版本号体系不同，不能混在一起比较。
    .OUTPUTS
        [bool]
    #>
    param($Entry)

    $command = ''
    if ($null -ne $Entry) {
        if ($Entry -is [System.Collections.IDictionary]) {
            if ($Entry.Contains('UninstallString')) { $command = [string]$Entry['UninstallString'] }
        } else {
            $prop = $Entry.PSObject.Properties['UninstallString']
            if ($prop -and $null -ne $prop.Value) { $command = [string]$prop.Value }
        }
    }
    $command = $command.Trim()
    if (-not $command) { return $false }
    return $command.StartsWith('msiexec', [StringComparison]::OrdinalIgnoreCase)
}
