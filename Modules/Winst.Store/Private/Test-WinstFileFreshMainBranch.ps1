#Requires -Version 5.1

function Test-WinstFileFreshMainBranch {
    <#
    .SYNOPSIS
        ②′ 版本号取自主包文件信息时，按调用方的判定强制重取主包并刷新校验器基线。
    .DESCRIPTION
        调用方按解析锁里的远端新鲜度决定主包要不要重新取——unchanged（远端无新包）时缓存里那份
        就是软件源当前这一份，沿用缓存（走正常校验器判定）；changed / unknown 才重新取包，取包时
        顺手发一次 HEAD：把校验器基线刷新成「本次取到的这份」——下载完成写回 fileMeta 时基线才是
        真实值。离线只能用缓存，文件自己声明了 refresh 时按声明走。
    .OUTPUTS
        [bool] 是否命中该分支
    #>
    param($Plan, [hashtable]$Context, [string]$Uri, [int]$FileIndex, [string]$RefreshRaw,
        [switch]$Offline, [switch]$CanCheckRemote, [switch]$FreshMain, [string]$Reason)

    if (-not $FreshMain -or $FileIndex -ne 0 -or $RefreshRaw -or $Offline) { return $false }
    if ($CanCheckRemote) { Set-WinstFilePlanValidators -Plan $Plan -Context $Context -Uri $Uri }
    $Plan['NeedDownload'] = $true
    $Plan['Reason'] = $Reason
    return $true
}
