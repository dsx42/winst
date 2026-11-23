#Requires -Version 5.1

function Get-WinstDefaultUpdateSource {
    <#
    .SYNOPSIS
        从已安装软件的可用计划中按更新优先级选取默认来源。
    #>
    param([hashtable]$Context, $Row, $Ledger, [string]$InstalledVersion, [hashtable]$Lookup = @{})

    $origin = Get-EntryString -Entry $Ledger -Key 'manifestOrigin'
    $sorted = Sort-WinstRowSources -Context $Context -Row $Row -Lookup $Lookup -InstalledVersion $InstalledVersion -Ledger $Ledger -OriginName $origin
    foreach ($entry in @($sorted['Sources'])) {
        if ($entry['Ok'] -and $entry['Plan']) { return $entry }
    }
}
