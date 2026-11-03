#Requires -Version 5.1

function Test-WinstFileVersionPriorBranch {
    <#
    .SYNOPSIS
        ②″ 版本优先判定：文件自身版本与下载时记账一致即命中，不一致则重取。
    .DESCRIPTION
        安装与仅下载操作共用：两侧都有「文件自身版本」时，用版本判断这个文件是否更新，避免下载地址、
        ETag 或 Last-Modified 漂移导致同版本重复下载。文件显式声明 refresh 时按声明处理。
        FreshMain 表示版本仅来自缓存包、尚未确认远端是否变化，不能用这个版本命中缓存。

        只认文件自身版本：主包恒有；附加文件只有声明 files[].versionListUrl 并由该文件独立解析出
        版本时才有（跟随主包版本的附加文件 FileVersion 为空）——否则主包一升版就会把内容没变的
        附加文件误判成「版本已变化」重新下载。
    .OUTPUTS
        [bool] 是否已得出结论（调用方据此继续下一个文件）
    #>
    param($Plan, $Meta, [int]$FileIndex, [switch]$FreshMain, [string]$RefreshRaw)

    if ($FreshMain -or $RefreshRaw) { return $false }

    $currentVersion = [string]$Plan['FileVersion']
    $recordedVersion = [string]$Meta.SourceVersion
    if (-not ($currentVersion -and $recordedVersion)) { return $false }

    $isCompanion = ($FileIndex -gt 0)
    if ((Compare-WinstVersion -A $recordedVersion -B $currentVersion) -eq 0) {
        $Plan['NeedDownload'] = $false
        if ($isCompanion) {
            $Plan['Reason'] = ('已缓存且附加文件版本未变（{0}）' -f $currentVersion)
        } else {
            $Plan['Reason'] = ('已缓存且版本未变（{0}）' -f $currentVersion)
        }
    } else {
        $Plan['NeedDownload'] = $true
        if ($isCompanion) {
            $Plan['Reason'] = ('附加文件版本已变化（{0} → {1}），将重新下载' -f $recordedVersion, $currentVersion)
        } else {
            $Plan['Reason'] = ('远端版本已变化（{0} → {1}），将重新下载' -f $recordedVersion, $currentVersion)
        }
    }
    return $true
}
