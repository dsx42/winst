#Requires -Version 5.1

function Get-WinstRecordedHash {
    <#
    .SYNOPSIS
        从索引条目里取某个包文件已记录的 sha256（大小写不敏感比较文件名）；没有返回空串。
    #>
    param($Entry, [string]$FileName)

    if ($null -eq $Entry -or -not $FileName) { return '' }
    $hashObj = Get-EntryValue -Entry $Entry -Key 'hashes' -Default $null
    if ($null -eq $hashObj) { return '' }
    if ($hashObj -is [System.Collections.IDictionary]) {
        foreach ($key in @($hashObj.Keys)) {
            if ([string]$key -ieq $FileName) { return ([string]$hashObj[$key]).ToLowerInvariant() }
        }
        return ''
    }
    foreach ($hp in $hashObj.PSObject.Properties) {
        if ($hp.Name -ieq $FileName) { return ([string]$hp.Value).ToLowerInvariant() }
    }
    return ''
}
