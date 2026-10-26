#Requires -Version 5.1

function Move-WinstItemInto {
    <#
    .SYNOPSIS
        把解压临时目录里的条目搬进目标目录；目标已有同名目录时递归合并（覆盖模式下不先删旧目录）。
    .DESCRIPTION
        $Source 必须是文件系统对象（Get-ChildItem / Get-Item 的结果）——函数按它的 Name / FullName /
        PSIsContainer 搬运；直接传路径字符串会因这些属性为 $null 而报「LiteralPath 为 null」（见
        Expand-WinstArchiveLayout 里 stripTopDir 指向单个文件的分支）。
    #>
    param(
        [Parameter(Mandatory = $true)][System.IO.FileSystemInfo]$Source,
        [Parameter(Mandatory = $true)][string]$DestDir
    )

    # 压缩包里的符号链接 / junction：搬到安装目录后，后续「清理模式」的递归删除会跟随链接删掉目标内容
    if (Test-WinstReparsePoint -Path $Source.FullName) {
        throw ('压缩包里含有重解析点（junction / 符号链接），已拒绝搬运：{0}' -f $Source.FullName)
    }

    $target = Join-WinstPath $DestDir $Source.Name
    if ((Test-Path -LiteralPath $target) -and (Test-WinstReparsePoint -Path $target)) {
        throw ('目标位置是重解析点，已拒绝覆盖：{0}' -f $target)
    }
    if ($Source.PSIsContainer) {
        if (Test-Path -LiteralPath $target -PathType Container) {
            foreach ($child in @(Get-ChildItem -LiteralPath $Source.FullName -Force -ErrorAction SilentlyContinue)) {
                Move-WinstItemInto -Source $child -DestDir $target
            }
            try { [IO.Directory]::Delete($Source.FullName, $false) } catch { }
            return
        }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue }
        Move-Item -LiteralPath $Source.FullName -Destination $target -Force -ErrorAction Stop
        return
    }

    Move-Item -LiteralPath $Source.FullName -Destination $DestDir -Force -ErrorAction Stop
}
