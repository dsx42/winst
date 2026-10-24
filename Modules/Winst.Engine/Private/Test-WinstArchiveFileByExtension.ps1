#Requires -Version 5.1

function Test-WinstArchiveFileByExtension {
    <#
    .SYNOPSIS
        按扩展名判断一个文件是不是压缩包。
    .DESCRIPTION
        命中即认为「指向的文件本身是压缩包，解压其内容到目标目录」而不是把它当普通文件搬过去：
        .7z / .zip / .tar / .gz / .tgz / .xz / .bz2 / .rar / .cab（7-Zip 引擎都认）。.exe 不在列——
        NSIS 安装器当主包走 installerExe 流程，指向 .exe 时语义是「取出这个文件」而非「解压它」。
    #>
    param([string]$Path)

    $ext = [IO.Path]::GetExtension([string]$Path).TrimStart('.').ToLowerInvariant()
    return (@('7z', 'zip', 'tar', 'gz', 'tgz', 'xz', 'bz2', 'rar', 'cab') -contains $ext)
}
