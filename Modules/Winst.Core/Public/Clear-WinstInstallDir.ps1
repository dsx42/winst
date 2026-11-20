#Requires -Version 5.1

function Clear-WinstInstallDir {
    <#
    .SYNOPSIS
        整目录清理 winst 的缓存、套件或临时内容。
    .DESCRIPTION
        指定 AllowedRoot 时只允许删除其子目录。Strict 将清理失败作为错误抛出，默认报告警告。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string]$AllowedRoot = '',
        [switch]$Strict
    )

    try {
        $directory = Get-WinstFileSystemItem -Path $Dir -AllowMissing
        if ($null -eq $directory -or -not $directory.PSIsContainer) { return }
        if ($AllowedRoot -and -not (Test-WinstPathUnderRoot -Path $directory.FullName -Root $AllowedRoot)) {
            throw ('拒绝清理允许根目录之外的目录：{0}' -f $Dir)
        }
        Remove-WinstDirectoryTree -Path $directory.FullName
    } catch {
        if ($Strict) { throw }
        Write-Warning ('未能清理目录 {0}：{1}' -f $Dir, $_.Exception.Message)
    }
}
