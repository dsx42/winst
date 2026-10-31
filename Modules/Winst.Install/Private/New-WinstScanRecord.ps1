#Requires -Version 5.1

function New-WinstScanRecord {
    <#
    .SYNOPSIS
        构造一条「扫描到的已装软件」记录，供目录 / 注册表 / 应用包三类扫描共用。
    .DESCRIPTION
        三个扫描函数（Get-WinstInstallDirRecords / Get-WinstRegistryScanRecords / Get-WinstAppxScanRecords）
        共用这一组字段，字段顺序必须一致（下游 Update-WinstLedgerFromScan 按名读取）。
        集中在这里，新增字段只改一处。

        `OldVersions` 是同一软件在本机并存的低版本（`[ordered]@{ version; detail; recordKey }`），
        由检测结果原样带上来，供台账记录后提醒用户清理。
    .OUTPUTS
        [ordered]@{ Id; Version; OldVersions; Type; InstallDir; Managed; Source; DirOnly; VerifiedIdentity }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Version = 'unknown',
        $OldVersions = @(),
        [string]$Type = '',
        [string]$InstallDir = '',
        [string]$Managed = 'winst',
        [string]$Source = '',
        [switch]$DirOnly,
        [switch]$VerifiedIdentity
    )

    $old = @()
    foreach ($item in @($OldVersions)) {
        $text = Get-EntryString -Entry $item -Key 'Version'
        if (-not $text) { $text = Get-EntryString -Entry $item -Key 'version' }
        if (-not $text) { continue }
        $old += [ordered]@{
            version   = $text
            detail    = (Get-EntryString -Entry $item -Key 'Detail')
            recordKey = (Get-EntryString -Entry $item -Key 'RecordKey')
        }
    }

    return [ordered]@{
        Id          = $Id
        Version     = $Version
        OldVersions = @($old)
        Type        = $Type
        InstallDir  = $InstallDir
        Managed     = $Managed
        Source      = $Source
        DirOnly     = [bool]$DirOnly
        VerifiedIdentity = [bool]$VerifiedIdentity
    }
}
