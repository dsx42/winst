#Requires -Version 5.1

function Test-WinstFileVersionPriorBranch {
    <#
    .SYNOPSIS
        ②″ 主包版本优先判定：远端版本与下载时记账一致即命中，不一致则重取。
    .DESCRIPTION
        安装与仅下载操作共用：两侧都有版本号时，使用版本判断主包是否更新，避免下载地址、
        ETag 或 Last-Modified 漂移导致同版本重复下载。文件显式声明 refresh 时按声明处理。
        FreshMain 表示版本仅来自缓存包、尚未确认远端是否变化，不能用这个版本命中缓存。
    .OUTPUTS
        [bool] 是否已得出结论（调用方据此继续下一个文件）
    #>
    param($Plan, $File, $Meta, [int]$FileIndex, [switch]$FreshMain, [string]$RefreshRaw)

    if ($FreshMain -or $FileIndex -ne 0 -or $RefreshRaw) { return $false }

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
