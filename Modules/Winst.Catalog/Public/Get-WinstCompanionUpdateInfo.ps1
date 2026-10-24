#Requires -Version 5.1

function Get-WinstCompanionUpdateInfo {
    <#
    .SYNOPSIS
        判断「主包命中缓存、只有配套文件有变化」，供更新前的提示与确认使用。
    .OUTPUTS
        @{ Checked; CompanionsOnly; ChangedCount; Names; Error }
    .DESCRIPTION
        内部走与安装流程同一套逐文件判定（Get-WinstPackageFilePlans -CheckValidators），因此
        校验器请求共用进程内 TTL 缓存、不会重复联网；`--offline` / `--dry-run` 下不发任何请求
        （校验器类判定退化为按名命中，但「地址 / 文件名变了」「摘要不一致」仍按本地判定照常报告）。
        只对有配套文件（`files[]` 第二条起）且不是 download 类型的条目做判定；installer 条目也判定
        。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan
    )

    $result = @{ Checked = $false; CompanionsOnly = $false; ChangedCount = 0; Names = @(); Error = '' }
    if ($null -eq $Plan) { return $result }
    $type = (Get-EntryString -Entry $Plan -Key 'type').Trim().ToLowerInvariant()
    if ($type -eq 'download') { return $result }

    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -lt 2) { return $result }
    $id = Get-EntryString -Entry $Plan -Key 'id'
    if (-not $id) { return $result }

    try {
        $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
        # -FreshMain：版本号取自主包文件信息的条目——unchanged（远端无新包）时主包沿用缓存，
        # 主包要重取（远端有新包 / 没比出结论）就不是「仅配套文件更新」
        $companionFreshMain = [bool](Get-EntryBool -Entry $Plan -Key 'versionFromPackage')
        if ($companionFreshMain -and ([string](Get-EntryString -Entry $Plan -Key 'remoteFresh')) -ieq 'unchanged') {
            # unchanged（远端无新包）：缓存里那份就是软件源当前这一份，主包沿用缓存
            $companionFreshMain = $false
        }
        $plans = @(Get-WinstPackageFilePlans -Context $Context -Index $indexRead.Index -Id $id -Files $files -CheckValidators `
            -FreshMain:$companionFreshMain -SourceVersion (Get-EntryString -Entry $Plan -Key 'version'))
    } catch {
        $result.Error = $_.Exception.Message
        return $result
    }
    if ($plans.Count -lt 2) { return $result }
    $result.Checked = $true
    if ([bool]$plans[0]['NeedDownload']) { return $result }   # 主包也要重取 → 走完整安装，不是「仅配套文件更新」

    for ($i = 1; $i -lt $plans.Count; $i++) {
        if ($plans[$i]['NeedDownload']) {
            $result.ChangedCount++
            $result.Names += [string]$plans[$i]['Name']
        }
    }
    if ($result.ChangedCount -gt 0) { $result.CompanionsOnly = $true }
    return $result
}
