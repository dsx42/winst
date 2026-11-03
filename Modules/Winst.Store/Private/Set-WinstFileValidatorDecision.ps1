#Requires -Version 5.1

function Set-WinstFileValidatorDecision {
    <#
    .SYNOPSIS
        ④ 收尾：发一次 HEAD 取校验器，按 files[].compare 列出的判据与索引记账比对，判定是否重取。
    .DESCRIPTION
        compare 缺省 = 最后修改时间 + 大小（ETag 在不少主机上阶段性漂移，不作为默认判据）；
        清单可以列出 etag / lastModified / size / checksum，这里只比列出的项（checksum 在 ③ 校验分支
        处理，或由 Get-WinstExpectedHash -IgnoreCachedHash 强制重取远端校验文件）。
        列出的判据一项都拿不到时，与「校验器拿不到」同口径：check 重取，其余退到 TTL 兜底并给出提示。
    #>
    param($Plan, [hashtable]$Context, $Meta, $Refresh, [string]$Name, [string]$Target,
        [bool]$HasLastChecked, [int]$AgeHours, [switch]$ChecksumVerified)

    $criteria = @((Get-WinstFileCompareCriteria -Text ([string]$Plan['Compare'])).Criteria)
    $compareText = [string]$Plan['Compare']

    # auto / check / ttl（到期）：发一次 HEAD 取校验器，与索引记账比对
    $validators = Get-WinstRemoteValidators -Context $Context -Uri ([string]$Plan['Url'])
    $unavailable = ''
    if (-not $validators.Ok) {
        $unavailable = [string]$validators.Error
    } elseif (-not $validators.ETag -and -not $validators.LastModified -and $null -eq $validators.Size) {
        $unavailable = '服务器没有提供可比对的校验信息'
    }

    if ($unavailable) {
        if ($ChecksumVerified) {
            $Plan['NeedDownload'] = $false
            $Plan['Reason'] = '已缓存且校验码一致（其它所选校验器不可用）'
            return
        }

        # 校验器拿不到：不否定缓存（见 12）。check 按重取处理，其余退到 TTL 兜底。
        # 命中（不下载）时 Reason 不会被打印，因此另给一行 Hint 让调用方一定提示用户
        # ——静默退化会让人误以为「已经确认过没变化」
        if ($Refresh.Mode -ne 'check' -and $HasLastChecked -and $AgeHours -lt $Refresh.MaxAgeHours) {
            $Plan['NeedDownload'] = $false
            $Plan['Reason'] = ('已缓存（{0} 小时前确认过；本次无法确认远端是否变化：{1}）' -f $AgeHours, $unavailable)
            $Plan['Hint'] = ('无法确认「{0}」是否变化（{1}），本次按已缓存处理' -f $Name, $unavailable)
            return
        }
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = ('无法确认这个文件是否变化（{0}），将重新下载' -f $unavailable)
        return
    }

    $localSize = $null
    if ($criteria -contains 'size') {
        try { $localSize = (Get-Item -LiteralPath $Target -Force -ErrorAction Stop).Length } catch { }
    }
    $comparison = Compare-WinstFileValidators -Criteria $criteria -Meta $Meta -Validators $validators -LocalSize $localSize
    $compared = [int]$comparison.Compared
    $remoteChanged = [bool]$comparison.Changed
    $baseline = [bool]$comparison.Baseline

    if ($compared -eq 0) {
        if ($ChecksumVerified) {
            $Plan['NeedDownload'] = $false
            $Plan['Reason'] = '已缓存且校验码一致（其它所选校验器不可用）'
            return
        }

        $unavailable = ('拿不到 compare 指定的判据（{0}）' -f $compareText)
        if ($Refresh.Mode -ne 'check' -and $HasLastChecked -and $AgeHours -lt $Refresh.MaxAgeHours) {
            $Plan['NeedDownload'] = $false
            $Plan['Reason'] = ('已缓存（{0} 小时前确认过；本次无法确认远端是否变化）' -f $AgeHours)
            $Plan['Hint'] = ('无法确认「{0}」是否变化（{1}），本次按已缓存处理' -f $Name, $unavailable)
            return
        }
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = ('无法确认这个文件是否变化（{0}），将重新下载' -f $unavailable)
        return
    }

    # 只有取得有效判据时才提交新基线，拿不到所选字段不能给 TTL 续期。
    $Plan['ValidatorETag'] = [string]$validators.ETag
    $Plan['ValidatorLastModified'] = [string]$validators.LastModified
    if ($null -ne $validators.Size) { $Plan['ValidatorSize'] = $validators.Size }
    $Plan['CheckedAt'] = (Get-Date).ToString('s')

    if ($remoteChanged) {
        $Plan['NeedDownload'] = $true
        if ($Meta.Exists -and $baseline) {
            $Plan['Reason'] = ('远端文件已变化（{0} 与索引记录不一致），将重新下载' -f $compareText)
        } else {
            $Plan['Reason'] = '首次确认这个文件的校验信息（索引里还没有基线），重新取一次以建立基线'
        }
        return
    }

    $Plan['NeedDownload'] = $false
    $Plan['Reason'] = '已缓存且远端未变化'
}
