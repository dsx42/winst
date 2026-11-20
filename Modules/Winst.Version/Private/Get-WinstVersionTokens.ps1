#Requires -Version 5.1

function Get-WinstVersionTokens {
    <#
    .SYNOPSIS
        把版本号按「数字串 / 字母串」切段（分隔符丢弃），供语义化比较使用。
    #>
    param([string]$Value)

    $found = Select-String -InputObject ([string]$Value) -Pattern '\p{Nd}+|\p{L}+' -AllMatches -CaseSensitive
    if ($found) {
        foreach ($match in $found.Matches) { $match.Value }
    }
}
