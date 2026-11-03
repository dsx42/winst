#Requires -Version 5.1

function Get-WinstFilePlan {
    <#
    .SYNOPSIS
        判定单个文件是否需要下载，返回该文件的计划条目（字段见 Get-WinstPackageFilePlans 的 .OUTPUTS）。
    .DESCRIPTION
        按 ① 缺失 → ②″ 版本优先 → ② 地址变化 → ②′ FreshMain → ③ 校验码 / ④ refresh 的顺序判定，
        每个分支只写计划字段，不打印、不改索引。
    #>
    param(
        [hashtable]$Context,
        $File,
        [int]$FileIndex,
        [string]$Dir,
        $Entry,
        [switch]$Offline,
        [switch]$DryRun,
        [switch]$CanCheckRemote,
        [switch]$FreshMain,
        [string]$FreshMainReason = ''
    )

    $url = Get-EntryString -Entry $File -Key 'url'
    $name = Get-EntryString -Entry $File -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }

    # name 会被直接拼进缓存目录（<pkgDir>\<id>\<name>）：只允许单个文件名，
    # 带分隔符 / .. / 非法字符的名字会写到缓存目录之外（含由 URL 派生的名字，同样要校验）
    $name = ([string]$name).Trim()
    if ($name -and -not (Test-WinstSafePathSegment -Name $name)) { $name = '' }

    $plan = New-WinstFilePlanEntry -File $File -Url $url -Name $name -FileIndex $FileIndex

    if (-not $name -or -not $url) {
        $plan['Reason'] = '下载信息不完整（文件名不合法或地址为空）'
        return $plan
    }
    $target = Join-WinstPath $Dir $name
    Assert-WinstSafeWritePath -Path $target
    $plan['Target'] = $target

    $refresh = Get-WinstFileRefreshMode -FileDecl $File
    $plan['Refresh'] = $refresh.Mode
    $plan['RefreshMaxAgeHours'] = $refresh.MaxAgeHours
    if ($refresh.Invalid) {
        $plan['Notice'] = ('软件源里的 refresh 取值「{0}」无法识别，已按 auto 处理' -f $refresh.Raw)
    }
    if (@(Get-EntryArray -Entry $File -Key 'compareInvalid').Count -gt 0) {
        $plan['Notice'] = ('软件源里的 compare 取值「{0}」无法识别，已按 auto 处理' -f ((Get-EntryArray -Entry $File -Key 'compareInvalid') -join '、'))
    }

    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Set-WinstFileMissingPlan -Plan $plan -Context $Context -Uri $url -CanCheckRemote:$CanCheckRemote
        return $plan
    }

    $meta = Get-WinstFileMeta -Entry $Entry -FileName $name
    $plan['CachedMeta'] = $meta
    $plan['MetaUrl'] = [string]$meta.Url
    $plan['ValidatorETag'] = [string]$meta.ETag
    $plan['ValidatorLastModified'] = [string]$meta.LastModified
    # 所有复用分支都携带已实测的摘要，避免版本 / refresh 快捷命中后写索引时又读取整个文件。
    $plan['RecordedHash'] = Get-WinstRecordedHash -Entry $Entry -FileName $name
    $plan['ExpectedAlgorithm'] = [string]$meta.ExpectedAlgorithm
    if ($meta.ExpectedAlgorithm -and $meta.ExpectedAlgorithm -ne 'SHA256') {
        $plan['ManifestHash'] = Get-WinstManifestHash -Entry $Entry -FileName $name -Algorithm $meta.ExpectedAlgorithm
    }

    # 离线规划使用已记录摘要，不请求远端；实际消费前另行重算当前文件摘要。
    $declaredHash = (Get-EntryString -Entry $File -Key 'hash').Trim()
    $declaredHashFile = (Get-EntryString -Entry $File -Key 'hashFile').Trim()

    # compare 显式含 checksum：强制重取远端校验文件（不复用索引里的指纹缓存）。
    # 地址固定的 hashFile（不随版本变化）只靠指纹永远判不出远端换了文件，需要清单显式开启这一次请求。
    $compareInfo = Get-WinstFileCompareCriteria -Text ([string]$plan['Compare'])
    $wantChecksum = (@($compareInfo.Criteria) -contains 'checksum')
    $ignoreCachedHash = [bool]($wantChecksum -and ($declaredHash -or $declaredHashFile))
    if ($wantChecksum -and -not $ignoreCachedHash) {
        $plan['Notice'] = ('软件源里的 compare 含 checksum，但这个文件没有声明 hash / hashFile，已按其余判据（{0}）处理' -f [string]$plan['Compare'])
    }
    if ($Offline -and ($declaredHash -or $declaredHashFile)) {
        $offlineExpected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $File -Offline `
            -CachedMeta $meta -FileUrl $url -FileVersion ([string]$plan['FileVersion'])
        if (-not $offlineExpected.Ok) {
            $plan['NeedDownload'] = $true
            $plan['Reason'] = '离线缓存缺少可验证的校验信息'
            $plan['Hint'] = [string]$offlineExpected.Error
            return $plan
        }
        Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target `
            -Expected $offlineExpected
        return $plan
    }

    if (-not $Offline -and (Get-EntryString -Entry $File -Key 'hashHeader')) {
        $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $File
        if (-not $expected.Ok -or $expected.Skipped) { throw '响应头摘要尚未解析，不能验证本地包' }
        Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target -Expected $expected -ForceRehash
        return $plan
    }
    $hasCurrentChecksumProvenance = $true
    if ($declaredHash) {
        # 版本相同只能在索引明确记录的是“当前字面摘要”时走快捷分支；若上次来自 hashFile，
        # 必须落到校验分支，更新摘要并清空旧来源记录。
        $hasCurrentChecksumProvenance = ([string]$meta.ExpectedHash -and
            ([string]$meta.ExpectedHash -ieq $declaredHash) -and
            -not [string]$meta.ChecksumHashFile -and -not [string]$meta.ChecksumFingerprint)
    } elseif ($declaredHashFile) {
        $currentFingerprint = Get-WinstChecksumDeclarationFingerprint -FileName $name -FileDecl $File `
            -FileUrl $url -FileVersion ([string]$plan['FileVersion'])
        $hasCurrentChecksumProvenance = ([string]$meta.ChecksumFingerprint -and
            ([string]$meta.ChecksumFingerprint -ieq $currentFingerprint))
    }
    if ($hasCurrentChecksumProvenance -and $compareInfo.IsDefault -and -not $ignoreCachedHash) {
        if (Test-WinstFileVersionPriorBranch -Plan $plan -Meta $meta -FileIndex $FileIndex `
                -FreshMain:$FreshMain -RefreshRaw ([string]$refresh.Raw)) {
            return $plan
        }
    }
    if (Test-WinstFileAddressBranch -Plan $plan -Meta $meta -Url $url) { return $plan }
    if (Test-WinstFileFreshMainBranch -Plan $plan -Context $Context -Uri $url -FileIndex $FileIndex `
            -RefreshRaw ([string]$refresh.Raw) -Offline:$Offline -CanCheckRemote:$CanCheckRemote `
            -FreshMain:$FreshMain -Reason $FreshMainReason) {
        return $plan
    }

    # 只读视图和预览只使用匹配的缓存摘要，不触发校验文件网络请求。
    $localOnly = [bool]($Offline -or -not $CanCheckRemote)
    $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $File -Offline:$localOnly `
        -CachedMeta $meta -FileUrl $url -FileVersion ([string]$plan['FileVersion']) -IgnoreCachedHash:($ignoreCachedHash -and $CanCheckRemote)
    if (-not $expected.Ok) {
        if ($Offline) {
            $plan['NeedDownload'] = $true
            $plan['Reason'] = '离线缓存缺少可验证的校验信息'
            $plan['Hint'] = [string]$expected.Error
            return $plan
        }
        # 无法取得声明的校验信息时，缓存不能被视为已验证；交给下载 / 校验阶段明确报错。
        $plan['NeedDownload'] = $true
        $plan['ValidationError'] = [string]$expected.Error
        $plan['ValidationNetwork'] = Get-EntryBool -Entry $expected -Key 'Network'
        $plan['Reason'] = '无法验证缓存的完整性'
        $plan['Hint'] = [string]$expected.Error
        return $plan
    }
    if ($expected.Skipped) {
        # ④ 未声明校验 → 按 files[].refresh 档位判定
        Set-WinstFileRefreshDecision -Plan $plan -Context $Context -Meta $meta -Refresh $refresh `
            -Name $name -Target $target -Offline:$Offline -DryRun:$DryRun -CanCheckRemote:$CanCheckRemote
        return $plan
    }

    # ③ 已声明校验 → 比对校验码
    Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target -Expected $expected
    if (-not $plan['NeedDownload'] -and $CanCheckRemote -and -not $compareInfo.IsDefault -and
            @($compareInfo.Criteria | Where-Object { $_ -ne 'checksum' }).Count -gt 0) {
        $refreshForComparison = @{ Mode = $refresh.Mode; MaxAgeHours = $refresh.MaxAgeHours }
        Set-WinstFileValidatorDecision -Plan $plan -Context $Context -Meta $meta -Refresh $refreshForComparison `
            -Name $name -Target $target -HasLastChecked:$false -AgeHours 0 -ChecksumVerified
    }
    return $plan
}
