#Requires -Version 5.1

function Get-PlanSourceKindText {
    <#
    .SYNOPSIS
        把下载来源类型翻译成普通用户能看懂的说明。
    #>
    param([string]$Kind)

    switch ($Kind) {
        'direct' { return '固定下载地址' }
        'github' { return 'GitHub 发布页' }
        'listing' { return '版本列表页' }
        'page' { return '软件官网下载页' }
        'json' { return 'JSON 下载接口' }
        'magnet' { return '磁力链接（BitTorrent）' }
        default {
            if ($Kind) { return $Kind }
            return '未知来源'
        }
    }
}
