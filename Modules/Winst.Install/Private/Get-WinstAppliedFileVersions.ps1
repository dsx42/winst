#Requires -Version 5.1

function Get-WinstAppliedFileVersions {
    <#
    .SYNOPSIS
        在附件落位成功后保存实际下载元数据；未重新落位的附件保留原快照。
    #>
    param([hashtable]$Context, [string]$Id, $Plans, $Ledger, $Landing, [switch]$CompanionOnly)

    $result = New-WinstOrdinalDictionary
    $previous = Get-EntryValue -Entry $Ledger -Key 'appliedFileVersions'
    if ($CompanionOnly -and $previous) {
        foreach ($name in $previous.Keys) { $result[$name] = $previous[$name] }
    }
    $index = (Read-WinstCacheIndex -PkgDir $Context.PkgDir).Index
    if (-not $index.Contains($Id)) { return ,$result }
    $fileMeta = Get-EntryValue -Entry $index[$Id] -Key 'fileMeta'
    for ($i = 1; $i -lt $Plans.Count; $i++) {
        $filePlan = $Plans[$i]
        $name = [string]$filePlan['Name']
        if (@($Landing.UpdatedNames) -notcontains $name) { continue }
        $meta = Get-EntryValue -Entry $fileMeta -Key $name
        if (-not $meta) { continue }
        $snapshot = Copy-WinstObjectShallow -InputObject $meta
        $snapshot['compare'] = [string]$filePlan['Compare']
        $snapshot['sha256'] = [string]$filePlan['IndexHash']
        $result[$name] = $snapshot
    }
    return ,$result
}