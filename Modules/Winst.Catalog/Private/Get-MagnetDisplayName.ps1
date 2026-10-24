#Requires -Version 5.1

function Get-MagnetDisplayName {
    <#
    .SYNOPSIS
        读取 magnet URI 的 dn 参数（即产出文件名）并做百分号解码。
    #>
    param([string]$Uri)

    $dn = Get-MagnetParameter -Uri $Uri -Name 'dn'
    if (-not $dn) { return '' }
    try { return [Uri]::UnescapeDataString($dn) } catch { return $dn }
}
