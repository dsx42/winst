#Requires -Version 5.1

function Compare-WinstFileValidators {
    <#
    .SYNOPSIS
        按指定判据比较远端校验器与本地基线；不读文件、不联网。
    .OUTPUTS
        @{ Compared; Changed; Baseline }
    #>
    param([string[]]$Criteria, $Meta, $Validators, $LocalSize = $null)

    $result = @{ Compared = 0; Changed = $false; Baseline = $false }
    foreach ($field in @(@('etag', 'ETag'), @('lastmodified', 'LastModified'))) {
        if ($Criteria -notcontains $field[0]) { continue }
        $remote = Get-EntryString -Entry $Validators -Key $field[1]
        if (-not $remote) { continue }
        $local = Get-EntryString -Entry $Meta -Key $field[1]
        $result.Compared++
        if ($local) { $result.Baseline = $true }
        if (-not $local -or -not [string]::Equals($remote, $local, [StringComparison]::Ordinal)) {
            $result.Changed = $true
        }
    }
    $remoteSize = Get-EntryValue -Entry $Validators -Key 'Size' -Default $null
    if ($Criteria -contains 'size' -and $null -ne $remoteSize -and $null -ne $LocalSize) {
        $result.Compared++
        $result.Baseline = $true
        if ([long]$remoteSize -ne [long]$LocalSize) { $result.Changed = $true }
    }
    return $result
}
