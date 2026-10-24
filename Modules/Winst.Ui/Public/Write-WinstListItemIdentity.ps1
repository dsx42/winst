#Requires -Version 5.1

function Write-WinstListItemIdentity {
    <#
    .SYNOPSIS
        输出列表项统一的「编号 + 名称 + 可选 id」前缀，不换行。
    #>
    param([Parameter(Mandatory = $true)]$Item, [Parameter(Mandatory = $true)][int]$Number)

    Write-Host ('  {0}) {1}' -f $Number, [string]$Item['DisplayName']) -NoNewline -ForegroundColor White
    if ([string]$Item['DisplayName'] -cne [string]$Item['Id']) {
        Write-Host ('  ({0})' -f [string]$Item['Id']) -NoNewline -ForegroundColor DarkGray
    }
}
