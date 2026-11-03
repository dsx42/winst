#Requires -Version 5.1

function Confirm-WinstCachedFilePlan {
    <#
    .SYNOPSIS
        使用缓存安装包前重算声明的摘要；联网损坏则重取，离线或无法校验则保留文件并报错。
    .OUTPUTS
        无；更新文件计划的校验结果、NeedDownload 或 ValidationError。
    #>
    param([hashtable]$Context, [System.Collections.IDictionary]$FilePlan, [switch]$Offline)

    if ($FilePlan['NeedDownload'] -or $FilePlan['ValidationError']) { return }
    $cachedMeta = $FilePlan['CachedMeta']
    # 本次规划可能已刷新远端摘要，优先使用它，避免退回索引里的旧期望值。
    if ($FilePlan['ExpectedHash']) { $cachedMeta = $FilePlan }
    $check = Test-WinstFileIntegrity -Context $Context -FilePath ([string]$FilePlan['Target']) `
        -FileDecl $FilePlan['Decl'] -FileUrl ([string]$FilePlan['Url']) `
        -FileVersion ([string]$FilePlan['FileVersion']) -Offline:$Offline -CachedMeta $cachedMeta
    if ($check.Ok) {
        if (-not $check.Skipped) { Set-WinstFilePlanIntegrityFromCheck -FilePlan $FilePlan -Check $check }
        return
    }
    if ($Offline -or -not $check.ActualHash) {
        $FilePlan['ValidationError'] = [string]$check.Error
        $FilePlan['ValidationNetwork'] = [bool]$check.Network
        return
    }
    $FilePlan['NeedDownload'] = $true
    $FilePlan['Reason'] = [string]$check.Error
}
