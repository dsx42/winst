#Requires -Version 5.1

function Write-WinstDetailHeader {
    <#
    .SYNOPSIS
        详情页页头（空行 + 名称 + 分隔线 + id 行）；三个详情页共用。
    .DESCRIPTION
        已下载包 / 软件列表 / 已装软件三个详情页共用同一段页头：
            Write-Host ''
            Write-Host ('  {0}' -f $Item['DisplayName'])   -ForegroundColor Cyan
            Write-Host ('  {0}' -f ('-' * 40))              -ForegroundColor DarkGray
            Write-WinstDetailField -Label 'id       ' -Value $Item['Id']
    #>
    param([Parameter(Mandatory = $true)]$Item)

    Write-Host ''
    Write-Host ('  {0}' -f [string]$Item['DisplayName']) -ForegroundColor Cyan
    Write-Host ('  {0}' -f ('-' * 40)) -ForegroundColor DarkGray
    Write-WinstDetailField -Label 'id       ' -Value ([string]$Item['Id'])
}
