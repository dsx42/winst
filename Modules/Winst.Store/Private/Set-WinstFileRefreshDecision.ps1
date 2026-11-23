#Requires -Version 5.1

function Set-WinstFileRefreshDecision {
    <#
    .SYNOPSIS
        ④ 未声明校验时的判定：先按 refresh 档位 / 离线 / 只读视图给出结论，再交给校验器比对。
    .DESCRIPTION
        档位：ifMissing = 存在即命中；always = 每次重取；ttl = 距 lastCheckedAt 未超 maxAgeHours 才命中；
        auto / check 继续走校验器；预览跳过联网检查。
    #>
    param($Plan, [hashtable]$Context, $Meta, $Refresh, [string]$Name, [string]$Target, $Criteria,
        [switch]$CanCheckRemote)

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
    $lastChecked = [datetime]::MinValue
    $hasLastChecked = $false
    if ($Meta.LastCheckedAt) {
        if ([datetime]::TryParse([string]$Meta.LastCheckedAt, [ref]$lastChecked)) { $hasLastChecked = $true }
    }
    $ageHours = 0
    if ($hasLastChecked) { $ageHours = [int][Math]::Floor(((Get-Date) - $lastChecked).TotalHours) }

    if ($Refresh.Mode -eq 'ttl' -and $hasLastChecked -and $ageHours -lt $Refresh.MaxAgeHours) {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = ('已缓存（{0} 小时前确认过，未超过 {1} 小时）' -f $ageHours, $Refresh.MaxAgeHours)
        return
    }
    if (-not $CanCheckRemote) {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = '已缓存（预览模式不做新鲜度确认）'
        return
    }

    Set-WinstFileValidatorDecision -Criteria $Criteria -Plan $Plan -Context $Context -Meta $Meta -Refresh $Refresh `
        -Name $Name -Target $Target -HasLastChecked:$hasLastChecked -AgeHours $ageHours
}
