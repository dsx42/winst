#Requires -Version 5.1

function Get-WinstListFiles {
    <#
    .SYNOPSIS
        列出当前清单目录下的全部清单文件（名称 / 路径 / 项数 / 修改时间）。
    .OUTPUTS
        @( [ordered]@{ Name; Path; Count; Modified } )；目录不存在时返回空数组
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $dir = Get-WinstListsDir -Context $Context
    $cache = Get-WinstState -Name WinstJsonCache
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }

    foreach ($file in @(Get-ChildItem -LiteralPath $dir -Filter '*.list' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)) {
        $key = 'list-count|' + $file.FullName
        $stamp = '{0}:{1}' -f $file.LastWriteTimeUtc.Ticks, $file.Length
        $cached = $cache[$key]
        if ($null -eq $cached -or $cached.Stamp -ne $stamp) {
            $read = Read-WinstList -Path $file.FullName -CountOnly
            $cached = @{ Stamp = $stamp; Count = $read.Count }
            if ($read.Ok) { $cache[$key] = $cached }
        }
        [ordered]@{
            Name     = [string]$file.Name
            Path     = [string]$file.FullName
            Count    = $cached.Count
            Modified = $file.LastWriteTime
        }
    }
}
