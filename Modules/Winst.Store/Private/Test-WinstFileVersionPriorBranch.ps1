#Requires -Version 5.1

function Test-WinstFileVersionPriorBranch {
    <#
    .SYNOPSIS
        ②″（仅下载类型）版本优先判定：主包版本与记账一致即命中，不一致则重取。
    .DESCRIPTION
        type: download 的主包，本次解析出的版本与下载时记录的 sourceVersion 一致 → 缓存命中
        （版本相同 = 软件源没有新包），不一致 → 重新下载。签名链接（飞牛官网这类 ?sign=…&t=… 每次
        解析都变）的地址与校验器都会阶段性漂移，LM / ETag / 地址对不上不代表有新包——这类条目两侧
        都有版本号时版本号说了算，跳过后面的地址比对与校验器比对。任一侧拿不到版本
        （如 versionFrom: "package" 的条目）或文件显式声明了 refresh 时，仍走原有判定链。
    .OUTPUTS
        [bool] 是否已得出结论（调用方据此继续下一个文件）
    #>
    param($Plan, $File, $Meta, [int]$FileIndex, [switch]$DownloadOnly, [string]$RefreshRaw)

    if (-not $DownloadOnly -or $FileIndex -ne 0 -or $RefreshRaw) { return $false }

    $currentVersion = [string](Get-EntryString -Entry $File -Key 'version')
    $recordedVersion = [string]$Meta.SourceVersion
    if (-not ($currentVersion -and $recordedVersion)) { return $false }

    if ((Compare-WinstVersion -A $recordedVersion -B $currentVersion) -eq 0) {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = ('已缓存且版本未变（{0}）' -f $currentVersion)
    } else {
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = ('远端版本已变化（{0} → {1}），将重新下载' -f $recordedVersion, $currentVersion)
    }
    return $true
}
