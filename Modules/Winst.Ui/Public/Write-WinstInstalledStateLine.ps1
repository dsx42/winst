#Requires -Version 5.1

function Write-WinstInstalledStateLine {
    <#
    .SYNOPSIS
        显示软件列表项的安装状态、版本与目录缺失提示。
    #>
    param([Parameter(Mandatory = $true)]$Item)

    Write-Host '     安装:   ' -NoNewline -ForegroundColor Gray
    if ([string]$Item['Type'] -eq 'download') {
        Write-Host '不适用（这类软件只下载软件包，不安装到电脑）' -NoNewline -ForegroundColor DarkGray
    } elseif (-not [bool]$Item['Installed']) {
        Write-Host '未安装' -NoNewline -ForegroundColor DarkGray
    } else {
        Write-Host ('已安装 {0}' -f [string]$Item['InstalledVersionText']) -NoNewline -ForegroundColor Gray
        $conclusion = Get-WinstVersionConclusion -Item $Item -Kind 'installed'
        Write-Host ('    {0}' -f [string]$conclusion['Text']) -NoNewline -ForegroundColor ([string]$conclusion['Color'])
        if ([bool]$Item['InstalledDirMissing']) { Write-Host '   [安装目录不存在]' -NoNewline -ForegroundColor Yellow }
    }
    Write-Host ''
}
