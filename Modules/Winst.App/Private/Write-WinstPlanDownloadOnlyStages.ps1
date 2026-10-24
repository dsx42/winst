#Requires -Version 5.1

function Write-WinstPlanDownloadOnlyStages {
    <#
    .SYNOPSIS
        仅下载类型（download）的 ② 安装 / ③ 删除 两段（这两段对其它类型不存在）。
    #>
    param([hashtable]$View)

    Write-ResolvedStage -Marker '②' -Label '安装' -Lines @('不适用：这类软件只下载软件包，不安装到电脑（不写安装记录、不改动系统设置）')
    $cleanLines = @()
    if ($View.PkgTarget) { $cleanLines += ('删除已下载的软件包: {0}' -f ($View.PkgTarget + '\')) }
    else { $cleanLines += '删除已下载的软件包' }
    Write-ResolvedStage -Marker '③' -Label '删除' -Lines $cleanLines
}
