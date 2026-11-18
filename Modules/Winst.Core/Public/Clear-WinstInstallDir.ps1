#Requires -Version 5.1

function Clear-WinstInstallDir {
    <#
    .SYNOPSIS
        清理安装目录：无 keep 时整目录删除，有 keep 时逐项删除并保留命中内容。
    .DESCRIPTION
        AllowedRoot 要求目录位于允许根目录之下；目录及祖先路径禁止经过重解析点。
        支持长路径，嵌套链接只删除链接自身，不进入链接目标。
        Strict 在路径被拒绝、枚举或删除失败时抛错；默认只提示，供临时目录尽力清理。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string[]]$Keep = @(),
        [string]$AllowedRoot = '',
        [switch]$Strict
    )

    try {
        $directory = Get-WinstFileSystemItem -Path $Dir -AllowMissing
        if ($null -eq $directory -or -not $directory.PSIsContainer) { return }
        $dirFull = $directory.FullName.TrimEnd('\')
        # 删除前拒绝盘根、系统及用户关键目录，也拒绝通过祖先 junction 到达的目录。
        if (Test-WinstProtectedDirectory -Path $dirFull) {
            throw ('拒绝清理受保护目录：{0}' -f $Dir)
        }
        if (($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ('拒绝清理重解析点：{0}' -f $Dir)
        }
        $pathRoot = [IO.Path]::GetPathRoot($directory.FullName)
        if (Test-WinstPathHasReparsePoint -Path $dirFull -Root $pathRoot) {
            throw ('拒绝清理经过重解析点或无法确认的目录：{0}' -f $Dir)
        }
        if ($AllowedRoot -and -not (Test-WinstPathUnderRoot -Path $dirFull -Root $AllowedRoot)) {
            throw ('拒绝清理允许根目录之外的目录：{0}' -f $Dir)
        }

        $Keep = @($Keep | Where-Object { $null -ne $_ })
        $rules = @(ConvertTo-WinstKeepRule -Keep $Keep)
        foreach ($item in @(Get-WinstChildItem -Path $dirFull)) {
            try { $null = Remove-WinstItemWithKeep -Item $item -Base $dirFull -Rules $rules }
            catch {
                if ($Strict) { throw }
                Write-Warning ('未能清理 {0}：{1}' -f $item.FullName, $_.Exception.Message)
            }
        }
        # 无 keep 时只做非递归删除，不跟随嵌套重解析点。
        if (@($Keep).Count -eq 0) { Remove-WinstFileSystemItem -Path $dirFull }
    } catch {
        if ($Strict) { throw }
        Write-Warning ('未能清理目录 {0}：{1}' -f $Dir, $_.Exception.Message)
    }
}
