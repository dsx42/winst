#Requires -Version 5.1

function Move-WinstItemInto {
    <#
    .SYNOPSIS
        把解压临时目录里的条目搬进目标目录；Copy 时复制并保留来源，同名目录递归合并。
    .DESCRIPTION
        Source 使用 Get-WinstFileSystemItem / Get-WinstChildItem 返回的条目，FullName 始终是普通完整路径。
        逐项接收刚枚举的来源属性；写入前实时核对目标父目录及同名条目，文件操作使用扩展路径。
    #>
    param(
        [Parameter(Mandatory = $true)]$Source,
        [Parameter(Mandatory = $true)][string]$DestDir,
        [switch]$Copy,
        [string]$DestIo
    )

    # 父级由入口及上层递归确认；复核当前父目录，避免对每个文件重复遍历整条路径链。
    if ($Copy) {
        $attrs = [IO.File]::GetAttributes($DestIo)
        if (($attrs -band [IO.FileAttributes]::Directory) -eq 0 -or ($attrs -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ('目标父目录不是普通目录，已拒绝交付：{0}' -f $DestDir)
        }
    }
    if (($Source.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('压缩包里含有重解析点（junction / 符号链接），已拒绝搬运：{0}' -f $Source.FullName)
    }

    $target = Join-WinstPath $DestDir $Source.Name
    $targetItem = Get-WinstFileSystemItem -Path $target -AllowMissing
    if ($null -ne $targetItem -and ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('目标位置是重解析点，已拒绝覆盖：{0}' -f $target)
    }
    if ($Source.PSIsContainer) {
        if (-not $Copy -and $null -eq $targetItem -and
                -not (Test-WinstPathUnderRoot -Path $target -Root $Source.FullName -AllowEqual) -and
                [IO.Path]::GetPathRoot($target) -ieq [IO.Path]::GetPathRoot($Source.FullName)) {
            [IO.Directory]::Move((ConvertTo-WinstExtendedPath -Path $Source.FullName), (ConvertTo-WinstExtendedPath -Path $target))
            return
        }
        if ($null -ne $targetItem -and -not $targetItem.PSIsContainer) {
            Remove-WinstFileSystemItem -Path $target
        }
        $targetIo = ConvertTo-WinstExtendedPath -Path $target
        $null = [IO.Directory]::CreateDirectory($targetIo)
        Get-WinstChildItem -Path $Source.FullName -ErrorAction Stop | ForEach-Object {
            Move-WinstItemInto -Source $_ -DestDir $target -Copy:$Copy -DestIo $targetIo
        }
        if (-not $Copy) { Remove-WinstFileSystemItem -Path $Source.FullName }
        return
    }

    if ($null -ne $targetItem -and $targetItem.PSIsContainer) {
        throw ('目标位置是目录，无法写入同名文件：' + $target)
    }
    $sourceIo = ConvertTo-WinstExtendedPath -Path $Source.FullName
    $targetIo = ConvertTo-WinstExtendedPath -Path $target
    if ($Copy) {
        # 与强制覆盖一致，目标的只读、隐藏和系统属性不能阻止写入；复制会带入来源文件属性。
        $blockingAttributes = [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
        if ($null -ne $targetItem -and ($targetItem.Attributes -band $blockingAttributes) -ne 0) {
            [IO.File]::SetAttributes($targetIo, ($targetItem.Attributes -band (-bnot $blockingAttributes)))
        }
        [IO.File]::Copy($sourceIo, $targetIo, $true)
    } else {
        if ($null -ne $targetItem) { Remove-WinstFileSystemItem -Path $target }
        [IO.File]::Move($sourceIo, $targetIo)
    }
}
