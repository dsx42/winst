#Requires -Version 5.1

function Save-WinstInstalledAppEntry {
    <#
    .SYNOPSIS
        写入单条安装记录并落盘：先重读最新台账，只覆盖这一条。
    .DESCRIPTION
        安装 / 更新流程在开始时读一份台账快照，中途可能被引擎自动安装（Confirm-WinstDownloadEngine /
        Confirm-WinstExtractEngine）、winst 自身更新等子流程写入过台账。此时拿手里的旧快照整份落盘，
        会把那些中途写入的记录整条抹掉，或者把已经更新过的版本号回滚成旧值。
        因此**条目级写入一律走本函数**：重读 → 只覆盖本条 → 落盘，其余条目以磁盘上的最新内容为准。

        两个时间戳由本函数统一盖章，调用方不需要也不应该自己写：
        - `installedAt`：首次安装时间。已有记录时沿用原值，自动更新不会把它改成今天。
        - `updatedAt`：最近一次写入台账的时间。两者不同即说明这条记录是被更新过的。

        台账无法解析、且备份失败时抛出异常（与 Read-WinstState 的口径一致），
        避免用不完整的内容覆盖唯一副本。
    .PARAMETER InstallRoot
        安装根目录（台账所在位置）。
    .PARAMETER Id
        要写入的条目 id。
    .PARAMETER Entry
        条目内容；`installedAt` / `updatedAt` 由本函数覆盖。
    .OUTPUTS
        [ordered] 实际写入的条目
    #>
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Entry
    )

    $stateRead = Read-WinstState -InstallRoot $InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        throw $stateRead.Error
    }
    $state = $stateRead.State

    $now = (Get-Date).ToString('s')
    $installedAt = ''
    $previous = Get-WinstInstalledApp -State $state -Id $Id
    if ($previous) { $installedAt = Get-EntryString -Entry $previous -Key 'installedAt' }
    if (-not $installedAt) { $installedAt = $now }

    $copy = [ordered]@{}
    foreach ($pair in @(Get-WinstEntryPairs -Entry $Entry)) { $copy[[string]$pair[0]] = $pair[1] }
    $copy['installedAt'] = $installedAt
    $copy['updatedAt'] = $now

    Set-WinstInstalledApp -State $state -Id $Id -Entry $copy
    Save-WinstState -InstallRoot $InstallRoot -State $state
    return $copy
}
