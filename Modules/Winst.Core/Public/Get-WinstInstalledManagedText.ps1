#Requires -Version 5.1

function Get-WinstInstalledManagedText {
    <#
    .SYNOPSIS
        把安装记录里的管理方式翻译成普通用户能看懂的说明。
    #>
    param([string]$Managed, [string]$Type)

    if ($Managed -and $Managed -ne 'winst') { return '仅登记（不是 winst 安装的）' }
    if ($Type -and $Type -eq 'download') { return '仅下载' }
    return 'winst 安装'
}
