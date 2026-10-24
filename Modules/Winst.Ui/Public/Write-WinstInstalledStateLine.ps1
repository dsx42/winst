#Requires -Version 5.1

function Write-WinstInstalledStateLine {
    <#
    .SYNOPSIS
        输出列表项的「安装状态」一行（已下载包 / 软件列表两个页面共用）。
    .DESCRIPTION
        三个列表页都有一行「本机安装情况」，其中「已下载包」与「软件列表」的这段逐字相同：
          仅下载类型 → 不适用（只下载软件包，不安装到电脑）
          未安装     → 未安装
          已安装     → 已安装 <版本> + Get-WinstVersionConclusion 的结论 + [安装目录不存在] 黄标
        只有行首标签不同（「本机安装: 」/「安装:   」），由 -Label 传入；行尾统一换行。
    #>
    param(
        [Parameter(Mandatory = $true)]$Item,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $line = '     ' + $Label
    Write-Host $line -NoNewline -ForegroundColor Gray
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
