#Requires -Version 5.1

function New-WinstScanRecord {
    <#
    .SYNOPSIS
        构造一条「扫描到的已装软件」记录，供目录 / 注册表 / 应用包三类扫描共用。
    .DESCRIPTION
        三个扫描函数（Get-WinstInstallDirRecords / Get-WinstRegistryScanRecords / Get-WinstAppxScanRecords）
        共用这一组 7 个字段，字段顺序必须一致（下游 Update-WinstLedgerFromScan 按名读取）。
        集中在这里，新增字段只改一处。
    .OUTPUTS
        [ordered]@{ Id; Version; Type; InstallDir; Managed; Source; DirOnly }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Version = 'unknown',
        [string]$Type = '',
        [string]$InstallDir = '',
        [string]$Managed = 'winst',
        [string]$Source = '',
        [switch]$DirOnly
    )

    return [ordered]@{
        Id         = $Id
        Version    = $Version
        Type       = $Type
        InstallDir = $InstallDir
        Managed    = $Managed
        Source     = $Source
        DirOnly    = [bool]$DirOnly
    }
}
