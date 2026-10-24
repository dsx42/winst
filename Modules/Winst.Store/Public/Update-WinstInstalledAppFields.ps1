#Requires -Version 5.1

function Update-WinstInstalledAppFields {
    <#
    .SYNOPSIS
        修改台账某条目的若干字段并落盘（重读最新 → 只覆盖这一条）。
    .DESCRIPTION
        「按实际值修正 installDir」「补写 appliedFiles」等操作统一在这里做浅拷贝 + 保存，
        收敛到这里：台账的读改写只有一条路径，后续加字段 / 加锁只需改这一处。
        落盘走 Save-WinstInstalledAppEntry（重读最新台账、只覆盖这一条），
        不用调用方手里的旧快照整份覆盖——调用方普遍在流程开始时读过一次台账，
        中途可能有引擎自动安装 / winst 自身更新写入过记录。
    .OUTPUTS
        修改后的条目（[ordered] 字典）
    #>
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)][hashtable]$Fields
    )

    $copy = [ordered]@{}
    foreach ($pair in @(Get-WinstEntryPairs -Entry $Entry)) { $copy[[string]$pair[0]] = $pair[1] }
    foreach ($key in @($Fields.Keys)) { $copy[[string]$key] = $Fields[$key] }
    return (Save-WinstInstalledAppEntry -InstallRoot $InstallRoot -Id $Id -Entry $copy)
}
