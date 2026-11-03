#Requires -Version 5.1

function Get-WinstAppliedFileVersions {
    <#
    .SYNOPSIS
        在附件落位成功后保存实际下载元数据；未重新落位的附件保留原快照。
    #>
    param([hashtable]$Context, [string]$Id, $Files, $Ledger, $Landing, [switch]$CompanionOnly)

    $result = New-WinstOrdinalDictionary
    $previous = Get-EntryValue -Entry $Ledger -Key 'appliedFileVersions'
    if ($CompanionOnly -and $previous) {
        foreach ($name in $previous.Keys) { $result[$name] = $previous[$name] }
    }
    $index = (Read-WinstCacheIndex -PkgDir $Context.PkgDir).Index
    if (-not $index.Contains($Id)) { return ,$result }
    $fileMeta = Get-EntryValue -Entry $index[$Id] -Key 'fileMeta'
    $list = @($Files)
    for ($i = 1; $i -lt $list.Count; $i++) {
        $file = $list[$i]
        $name = Get-EntryString -Entry $file -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url (Get-EntryString -Entry $file -Key 'url') }
        if (@($Landing.UpdatedNames) -notcontains $name) { continue }
        $meta = Get-EntryValue -Entry $fileMeta -Key $name
        if (-not $meta) { continue }
        $snapshot = Copy-WinstObjectShallow -InputObject $meta
        $snapshot['compare'] = Get-EntryString -Entry $file -Key 'compare'
        $result[$name] = $snapshot
    }
    return ,$result
}