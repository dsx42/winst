#Requires -Version 5.1

function Get-WinstMissingLedgerDirs {
    <#
    .SYNOPSIS
        ⑥ 找出台账里记录存在、但安装目录已不存在的条目（只报告，不改记录）。
    .OUTPUTS
        @( [ordered]@{ Id; InstallDir; Managed } )
    #>
    param($State)

    # repair 只写 state.json：不删环境变量、不删快捷方式等任何文件；
    # 目录缺失 / 记录异常的软件请由用户按需「重新安装 / 更新 / 卸载」处理。
    $missingDirs = @()
    $installed = $State['Installed']
    if (-not $installed) { return $missingDirs }
    foreach ($id in @($installed.Keys)) {
        $entry = $installed[$id]
        $dir = Get-EntryString -Entry $entry -Key 'installDir'
        if (-not $dir) { continue }
        if (Test-Path -LiteralPath $dir -PathType Container) { continue }
        $missingDirs += [ordered]@{
            Id         = [string]$id
            InstallDir = $dir
            Managed    = (Get-EntryString -Entry $entry -Key 'managed')
        }
    }
    return $missingDirs
}
