#Requires -Version 5.1

function Find-WinstOrphanRegistryRecords {
    <#
    .SYNOPSIS
        找出「显示名带指定版本、但卸载程序文件已经不存在」的系统安装记录（孤儿记录）。
    .DESCRIPTION
        用内层 MSI 卸掉某个版本后，外层 burn 引导包的注册记录可能还留在系统里，
        而它的卸载程序（`%ProgramData%\Package Cache` 下）早已被清理。这类记录的唯一作用
        就是让「设置 → 应用」里继续显示这个已卸掉的软件，属于可以安全清理的残留。
    .OUTPUTS
        [string[]]：命中记录的卸载键路径（每条都是卸载记录分支下的键）
    #>
    param($Plan, [string]$Version)

    $keys = @()
    $matched = @(Find-WinstRecordsForVersion -Plan $Plan -Version $Version)
    foreach ($hit in $matched) {
        if (Test-WinstUninstallerUsable -Entry $hit) { continue }
        $key = [string]$hit['KeyPath']
        if ($key -and $keys -notcontains $key) { $keys += $key }
    }
    return $keys
}
