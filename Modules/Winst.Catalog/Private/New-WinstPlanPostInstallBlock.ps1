#Requires -Version 5.1

function New-WinstPlanPostInstallBlock {
    <#
    .SYNOPSIS
        ⑤ 安装后命令（postInstall）→ 解析锁的 postInstall 段。
    #>
    param($Entry, [string]$Version)

    $postList = @()
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'postInstall')) {
        $exeText = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'exe') -Version $Version
        if (-not $exeText) { continue }
        $commandBlock = [ordered]@{
            exe        = $exeText
            args       = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'args') -Version $Version
            timeoutSec = (Get-EntryInt -Entry $item -Key 'timeoutSec' -Default 600)
        }
        if (Get-EntryBool -Entry $item -Key 'requireAdmin') { $commandBlock['requireAdmin'] = $true }
        $postList += $commandBlock
    }
    return $postList
}
