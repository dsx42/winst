#Requires -Version 5.1

function Set-WinstFileMissingPlan {
    <#
    .SYNOPSIS
        ① 缓存里没有这个文件：标记需要下载，允许联网时顺带建立校验器基线。
    .DESCRIPTION
        首次下载也先发一次 HEAD 建立校验器基线：否则下载记账里没有 ETag / Last-Modified，
        下一次新鲜度确认会把「基线为空」误判成「远端已变化」而白下载一次。探测失败不阻塞下载。
    #>
    param($Plan, [hashtable]$Context, [string]$Uri, [switch]$CanCheckRemote)

    $Plan['Reason'] = '缓存里没有这个文件'
    if (-not $CanCheckRemote) { return }
    Set-WinstFilePlanValidators -Plan $Plan -Context $Context -Uri $Uri -RequireFields
}
