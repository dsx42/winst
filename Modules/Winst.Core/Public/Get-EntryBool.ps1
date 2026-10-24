#Requires -Version 5.1

function Get-EntryBool {
    <#
    .SYNOPSIS
        读取布尔字段，兼容 JSON 布尔与字符串写法（true/false、1/0、yes/no、on/off）。
    #>
    param(
        $Entry,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [bool]$Default = $false
    )

    $value = Get-EntryValue -Entry $Entry -Key $Key -Default $null
    if ($null -eq $value) { return $Default }
    if ($value -is [bool]) { return $value }
    $text = ([string]$value).Trim()
    if (-not $text) { return $Default }
    if ($text -ieq 'true' -or $text -eq '1' -or $text -ieq 'yes' -or $text -ieq 'on') { return $true }
    if ($text -ieq 'false' -or $text -eq '0' -or $text -ieq 'no' -or $text -ieq 'off') { return $false }
    return $Default
}
