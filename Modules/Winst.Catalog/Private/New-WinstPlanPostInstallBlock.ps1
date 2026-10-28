#Requires -Version 5.1

function New-WinstPlanPostInstallBlock {
    <#
    .SYNOPSIS
        ⑤ 安装后命令（postInstall）→ 解析锁的 postInstall 段。
    #>
    param($Entry, [string]$Version)

    return (New-WinstPlanCommandList -Commands (Get-EntryArray -Entry $Entry -Key 'postInstall') -Version $Version)
}
