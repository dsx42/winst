#Requires -Version 5.1

function Set-WinstFileRefreshDecision {
    <#
    .SYNOPSIS
        ④ 未声明校验时的判定：先按 refresh 档位 / 离线 / 只读视图给出结论，再交给校验器比对。
    .DESCRIPTION
        档位：ifMissing = 存在即命中；always = 每次重取；ttl = 距 lastCheckedAt 未超 maxAgeHours 才命中；
        auto / check 继续走校验器。offline 与「不发请求的三种情形」在这里短路（只读视图零联网由构造保证，
        不要在这里加任何网络调用。
    #>
    param($Plan, [hashtable]$Context, $File, $Meta, $Refresh, [int]$FileIndex, [string]$Name, [string]$Target,
        [switch]$Offline, [switch]$DryRun, [switch]$CanCheckRemote)

    $lastChecked = [datetime]::MinValue
    $hasLastChecked = $false
    if ($Meta.LastCheckedAt) {
        if ([datetime]::TryParse([string]$Meta.LastCheckedAt, [ref]$lastChecked)) { $hasLastChecked = $true }
    }
    $ageHours = 0
    if ($hasLastChecked) { $ageHours = [int][Math]::Floor(((Get-Date) - $lastChecked).TotalHours) }

    if ($Offline) {
        # 严格离线：校验器请求整段跳过，各档都退化为「缓存里有就用」
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = '已缓存（离线模式不做新鲜度确认）'
        return
    }
    if ($Refresh.Mode -eq 'ifMissing') {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = '已缓存（refresh: ifMissing，不做新鲜度确认）'
        return
    }
    if ($Refresh.Mode -eq 'always') {
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = '已声明每次重新取（refresh: always）'
        return
    }
    if ($Refresh.Mode -eq 'ttl' -and $hasLastChecked -and $ageHours -lt $Refresh.MaxAgeHours) {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = ('已缓存（{0} 小时前确认过，未超过 {1} 小时）' -f $ageHours, $Refresh.MaxAgeHours)
        return
    }
    if (-not $CanCheckRemote) {
        # 不发请求的三种情形：调用方没开 -CheckValidators（只读视图走的路径）、--offline、--dry-run。
        # 这条分支是「只读视图零联网」由构造保证的地方——不要在这里加任何网络调用
        $Plan['NeedDownload'] = $false
        if ($DryRun) {
            $Plan['Reason'] = '已缓存（预览模式不做新鲜度确认）'
        } else {
            $Plan['Reason'] = '已缓存（未做新鲜度确认）'
        }
        return
    }

    Set-WinstFileValidatorDecision -Plan $Plan -Context $Context -File $File -Meta $Meta -Refresh $Refresh `
        -FileIndex $FileIndex -Name $Name -Target $Target -HasLastChecked:$hasLastChecked -AgeHours $ageHours
}
