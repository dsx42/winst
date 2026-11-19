#Requires -Version 5.1

function Move-WinstItemInto {
    <#
    .SYNOPSIS
        把选中的解压条目移入布局目录，同名目录递归合并。
    .DESCRIPTION
        Source 使用 Get-WinstFileSystemItem / Get-WinstChildItem 返回的条目，FullName 始终是普通完整路径。
        逐项接收刚枚举的来源属性；写入前实时核对目标父目录及同名条目，文件操作使用扩展路径。
    #>
    param(
        [Parameter(Mandatory = $true)]$Source,
        [Parameter(Mandatory = $true)][string]$DestDir
    )

    if (($Source.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('压缩包里含有重解析点（junction / 符号链接），已拒绝搬运：{0}' -f $Source.FullName)
    }

    $target = Join-WinstPath $DestDir $Source.Name
    $targetItem = Get-WinstFileSystemItem -Path $target -AllowMissing
    if ($null -ne $targetItem -and ($targetItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw ('目标位置是重解析点，已拒绝覆盖：{0}' -f $target)
    }
    if ($Source.PSIsContainer) {
        if ($null -eq $targetItem -and
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
            Move-WinstItemInto -Source $_ -DestDir $target
        }
        Remove-WinstFileSystemItem -Path $Source.FullName
        return
    }

    if ($null -ne $targetItem -and $targetItem.PSIsContainer) {
        throw ('目标位置是目录，无法写入同名文件：' + $target)
    }
    $sourceIo = ConvertTo-WinstExtendedPath -Path $Source.FullName
    $targetIo = ConvertTo-WinstExtendedPath -Path $target
    if ($null -ne $targetItem) { Remove-WinstFileSystemItem -Path $target }
    [IO.File]::Move($sourceIo, $targetIo)
}
