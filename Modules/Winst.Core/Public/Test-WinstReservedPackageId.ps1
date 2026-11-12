#Requires -Version 5.1

function Test-WinstReservedPackageId {
    <#
    .SYNOPSIS
        判断软件 id 是否占用了安装包根目录的保留目录名（Windows 大小写不敏感）。
    #>
    param([string]$Id)
    return $Id -ieq 'manifests'
}
