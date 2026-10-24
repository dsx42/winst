#Requires -Version 5.1

function Get-WinstRowViewFacts {
    <#
    .SYNOPSIS
        汇总软件清单行在各列表视图共用的名称、分组、来源、最佳版本、类型与远端新鲜度事实。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        $Row = $null,
        $Ledger = $null
    )

    $displayName = $Id
    $description = ''
    $sourceText = ''
    $group = ''
    $bestVersion = ''
    $bestSource = ''
    $inCatalog = [bool]($null -ne $Row)
    if ($Row) {
        $rowName = Get-EntryString -Entry $Row -Key 'Name'
        if ($rowName) { $displayName = $rowName }
        $description = Get-EntryString -Entry $Row -Key 'Description'
        $sourceText = Get-WinstRowSourceText -Row $Row
        $group = Get-WinstRowGroup -Row $Row
        $best = Get-WinstRowBestEntry -Row $Row
        if ($best) {
            $bestVersion = [string]$best['Version']
            $bestSource = [string]$best['Source']
        }
    }
    if (-not $group -and $Ledger) { $group = (Get-EntryString -Entry $Ledger -Key 'group').Trim() }

    $type = ''
    if ($Ledger) { $type = (Get-EntryString -Entry $Ledger -Key 'type').Trim().ToLowerInvariant() }
    if (-not $type -and $Row) { $type = Get-WinstRowType -Row $Row }

    $versionFromPackage = Test-WinstRowVersionFromPackage -Row $Row
    $remoteFresh = ''
    if ($versionFromPackage) { $remoteFresh = Get-WinstRowRemoteFreshState -Row $Row }

    return [ordered]@{
        Id                 = $Id
        DisplayName        = $displayName
        Description        = $description
        Group              = $group
        SourceText         = $sourceText
        BestVersion        = $bestVersion
        BestSource         = $bestSource
        InCatalog          = $inCatalog
        Type               = $type
        VersionFromPackage = [bool]$versionFromPackage
        RemoteFresh        = $remoteFresh
        Row                = $Row
    }
}
