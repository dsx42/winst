#Requires -Version 5.1

function Write-WinstDetailHeader {
    <#
    .SYNOPSIS
        详情页页头（空行 + 名称 + 分隔线 + id 行）；三个详情页共用。
    #>
    param([Parameter(Mandatory = $true)]$Item)

    Write-Host ''
    Write-Host ('  {0}' -f [string]$Item['DisplayName']) -ForegroundColor Cyan
    Write-Host ('  {0}' -f ('-' * 40)) -ForegroundColor DarkGray
    Write-Host ('    id       : {0}' -f $Item['Id']) -ForegroundColor Gray
    Write-WinstCompanionVersions -Item $Item
}
