#Requires -Version 5.1

function Get-WinstListFiles {
    <#
    .SYNOPSIS
        列出 <数据根>\lists\ 下的全部清单文件（名称 / 路径 / 项数 / 修改时间）。
    .OUTPUTS
        @( [ordered]@{ Name; Path; Count; Modified } )；目录不存在时返回空数组
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $dir = Get-WinstListsDir -Context $Context
    $files = @()
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }

    foreach ($file in @(Get-ChildItem -LiteralPath $dir -Filter '*.list' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)) {
        $read = Read-WinstList -Path $file.FullName
        $files += [ordered]@{
            Name     = [string]$file.Name
            Path     = [string]$file.FullName
            Count    = @($read.Entries).Count
            Modified = $file.LastWriteTime
        }
    }
    return @($files)
}
