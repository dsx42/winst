#Requires -Version 5.1

function New-WinstPlanCommandList {
    <#
    .SYNOPSIS
        把清单里的命令条目数组（postInstall / uninstall.commands）展开成解析锁里的命令段。
    .DESCRIPTION
        两种命令共用同一结构（见 docs\manifest.md 的「命令条目」）：只保留声明了 exe 的规则，
        版本占位符在这里展开，timeoutSec 缺省 600，requireAdmin 为真时才写进块里。

        这是该结构唯一的展开实现：新增字段时只改这里，两条命令路径不会各走一遍。
    .OUTPUTS
        @( [ordered]@{ exe; args; timeoutSec; requireAdmin } )
    #>
    param($Commands, [string]$Version)

    $list = @()
    foreach ($item in @($Commands)) {
        $exeText = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'exe') -Version $Version
        if (-not $exeText) { continue }
        $commandBlock = [ordered]@{
            exe        = $exeText
            args       = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'args') -Version $Version
            timeoutSec = (Get-EntryInt -Entry $item -Key 'timeoutSec' -Default 600)
        }
        if (Get-EntryBool -Entry $item -Key 'requireAdmin') { $commandBlock['requireAdmin'] = $true }
        $list += $commandBlock
    }
    return $list
}
