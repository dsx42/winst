#Requires -Version 5.1

function Format-WinstInstallResultMessage {
    <#
    .SYNOPSIS
        安装结果消息（系统项被跳过时带一句说明；installer 解析不出目录时明说）。
    .OUTPUTS
        [string]
    #>
    param($Plan, [string]$Method, [string]$InstallDir, [string]$Version, [bool]$SystemItemsSkipped, [switch]$FilesOnly)

    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = Get-EntryString -Entry $Plan -Key 'id' }

    # 系统项被跳过时结论里带一句说明（两种口径的措辞分开：CLI 的 --files-only 比「更新方式」更彻底）
    $filesOnlyNote = ''
    if ($SystemItemsSkipped) {
        if ($FilesOnly) { $filesOnlyNote = '（仅更新文件，未处理环境变量 / PATH / 快捷方式）' }
        else { $filesOnlyNote = '（只更新文件，环境变量 / PATH / 快捷方式保持原样）' }
    }
    if ($InstallDir) {
        return ('{0} {1} 已安装到 {2}{3}' -f $displayName, $Version, $InstallDir, $filesOnlyNote)
    }
    if ($Method -eq 'installer') {
        # installer 的安装位置由安装程序决定，winst 未能解析出实际目录时明说，不假装知道
        return ('{0} {1} 已安装（安装位置由安装程序决定）{2}' -f $displayName, $Version, $filesOnlyNote)
    }
    return ('{0} {1} 已安装{2}' -f $displayName, $Version, $filesOnlyNote)
}
