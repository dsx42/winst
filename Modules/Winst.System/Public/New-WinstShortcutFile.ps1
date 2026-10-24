#Requires -Version 5.1

function New-WinstShortcutFile {
    <#
    .SYNOPSIS
        创建 / 覆盖一个 .lnk 快捷方式。
    .DESCRIPTION
        目标 / 起始位置 / 备注都通过 Shortcut 对象设置后 Save 落盘；
        **只创建普通 .lnk**（开始菜单 / 任务栏按目标程序自身的标识分组）。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$WorkingDirectory = '',
        [string]$Description = ''
    )

    $parent = Split-Path -Parent $LinkPath
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction SilentlyContinue
    }
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($LinkPath)
    $lnk.TargetPath = $TargetPath
    if ($WorkingDirectory) { $lnk.WorkingDirectory = $WorkingDirectory }
    if ($Description) { $lnk.Description = $Description }
    $lnk.Save()
}
