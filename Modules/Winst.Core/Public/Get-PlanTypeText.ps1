#Requires -Version 5.1

function Get-PlanTypeText {
    <#
    .SYNOPSIS
        把条目类型翻译成普通用户能看懂的说明。
    #>
    param([string]$Type)

    $Type = ConvertTo-WinstEntryType -Type $Type
    switch ($Type) {
        'portable' { return '免安装版（解压就能用）' }
        'file' { return '单文件（下载就能用）' }
        'installer' { return '安装版（需要运行安装程序）' }
        'download' { return '只下载软件包，不安装到电脑' }
        default {
            if ($Type) { return $Type }
            return '未知'
        }
    }
}
