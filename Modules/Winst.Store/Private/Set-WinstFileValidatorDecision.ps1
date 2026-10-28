#Requires -Version 5.1

function Set-WinstFileValidatorDecision {
    <#
    .SYNOPSIS
        ④ 收尾：发一次 HEAD 取校验器，与索引记账比对（或按附加文件版本 / 大小）判定是否重取。
    #>
    param($Plan, [hashtable]$Context, $File, $Meta, $Refresh, [int]$FileIndex, [string]$Name, [string]$Target,
        [bool]$HasLastChecked, [int]$AgeHours)

    # 附加文件的版本判据：独立取版的附加文件（versionListUrl 等）
    # 解析出的版本与索引里记录的 sourceVersion 一致 → 直接命中——版本相同 = 附加包没有更新，
    # LM / ETag 的阶段性漂移不影响附加文件；不一致 → 重取。拿不到版本信息（记录为空）的
    # 文件仍走下面的校验器比对（LM + 大小，或 compare: size 的仅大小）
    if ($FileIndex -gt 0) {
        $fileVersionText = [string](Get-EntryString -Entry $File -Key 'version')
        $recordedVersion = [string]$Meta.SourceVersion
        if ($fileVersionText -and $recordedVersion) {
            if ($recordedVersion -ieq $fileVersionText) {
                $Plan['NeedDownload'] = $false
                $Plan['Reason'] = ('已缓存且附加文件版本未变（{0}）' -f $fileVersionText)
            } else {
                $Plan['NeedDownload'] = $true
                $Plan['Reason'] = ('附加文件版本已变化（{0} → {1}），将重新下载' -f $recordedVersion, $fileVersionText)
            }
            return
        }
    }

    # auto / check / ttl（到期）：发一次 HEAD 取校验器，与索引记账比对
    $validators = Get-WinstRemoteValidators -Context $Context -Uri ([string]$Plan['Url'])
    $unavailable = ''
    if (-not $validators.Ok) {
        $unavailable = [string]$validators.Error
    } elseif (-not $validators.ETag -and -not $validators.LastModified -and $null -eq $validators.Size) {
        $unavailable = '服务器没有提供可比对的校验信息'
    }

    if ($unavailable) {
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

    # 有可比对的校验器：与索引记账逐项比对（记录里有哪一项就比哪一项）。
    # files[].compare: "size" 时只比大小——dl.google.com 这类 Last-Modified 阶段性漂移的
    # 主机用；缺省比 ETag + Last-Modified + 大小
    $sizeOnly = ((Get-EntryString -Entry $File -Key 'compare').Trim().ToLowerInvariant() -ieq 'size')
    $checkedAt = (Get-Date).ToString('s')
    $Plan['ValidatorETag'] = [string]$validators.ETag
    $Plan['ValidatorLastModified'] = [string]$validators.LastModified
    if ($null -ne $validators.Size) { $Plan['ValidatorSize'] = $validators.Size }
    $Plan['CheckedAt'] = $checkedAt

    $remoteChanged = $false
    $compared = 0
    if (-not $sizeOnly -and $validators.ETag) {
        $compared++
        if (-not $Meta.ETag -or $validators.ETag -ine $Meta.ETag) { $remoteChanged = $true }
    }
    if (-not $sizeOnly -and $validators.LastModified) {
        $compared++
        if (-not $Meta.LastModified -or $validators.LastModified -ine $Meta.LastModified) { $remoteChanged = $true }
    }
    $localSize = $null
    try { $localSize = (Get-Item -LiteralPath $Target -Force).Length } catch { $localSize = $null }
    if ($null -ne $validators.Size -and $null -ne $localSize) {
        $compared++
        if ([long]$validators.Size -ne [long]$localSize) { $remoteChanged = $true }
    }
    if ($sizeOnly -and -not ($null -ne $validators.Size -and $null -ne $localSize)) {
        # 仅大小模式但拿不到大小可比：与「校验器拿不到」同口径（check 重取，其余 TTL 兜底）
        if ($Refresh.Mode -ne 'check' -and $HasLastChecked -and $AgeHours -lt $Refresh.MaxAgeHours) {
            $Plan['NeedDownload'] = $false
            $Plan['Reason'] = ('已缓存（{0} 小时前确认过；本次无法确认远端是否变化）' -f $AgeHours)
            $Plan['Hint'] = ('无法确认「{0}」是否变化（拿不到文件大小），本次按已缓存处理' -f $Name)
            return
        }
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = '无法确认这个文件是否变化（拿不到文件大小），将重新下载'
        return
    }

    if ($remoteChanged) {
        $Plan['NeedDownload'] = $true
        # 区分两种情况：索引里有基线但与远端不一致 = 远端真的变了；
        # 索引里还没有基线（首次下载没记账 ETag / HEAD 没拿到）= 只是首次建立基线，不误导用户
        if ($compared -gt 0 -and $Meta.Exists -and ($Meta.ETag -or $Meta.LastModified)) {
            $Plan['Reason'] = '远端文件已变化（校验信息与索引记录不一致），将重新下载'
        } else {
            $Plan['Reason'] = '首次确认这个文件的校验信息（索引里还没有基线），重新取一次以建立基线'
        }
        return
    }

    $Plan['NeedDownload'] = $false
    $Plan['Reason'] = '已缓存且远端未变化'
}
