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
        [string]$ManifestOrigin,
        [int]$FileIndex,
        [string]$Dir,
        $Entry,
        [switch]$Offline,
        [switch]$CanCheckRemote,
        [switch]$FreshMain,
        [switch]$RequireCurrent,
        [string]$FreshMainReason,
        [string]$UnchangedMainHash
    )

    $url = Get-EntryString -Entry $File -Key 'url'
    $name = Get-EntryString -Entry $File -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }

    # name 会被直接拼进缓存目录（<pkgDir>\<id>\<name>）：只允许单个文件名，
    # 带分隔符 / .. / 非法字符的名字会写到缓存目录之外（含由 URL 派生的名字，同样要校验）
    $name = ([string]$name).Trim()
    if ($name -and -not (Test-WinstSafePathSegment -Name $name)) { $name = '' }

    $plan = New-WinstFilePlanEntry -File $File -Url $url -Name $name -FileIndex $FileIndex

    $plan['ManifestOrigin'] = $ManifestOrigin
    if (-not $name -or -not $url) {
        $plan['Reason'] = '下载信息不完整（文件名不合法或地址为空）'
        return $plan
    }
    $target = Join-WinstPath $Dir $name
    Assert-WinstSafeWritePath -Path $target
    $plan['Target'] = $target

    $refresh = Get-WinstFileRefreshMode -FileDecl $File
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
    # 所有复用分支都携带已实测的摘要，避免版本 / refresh 快捷命中后写索引时又读取整个文件。
    $plan['IndexHash'] = Get-WinstRecordedHash -Entry $Entry -FileName $name
    $plan['ExpectedAlgorithm'] = [string]$meta.ExpectedAlgorithm
    if ($meta.ExpectedAlgorithm -and $meta.ExpectedAlgorithm -ne 'SHA256') {
        $plan['ManifestHash'] = Get-WinstManifestHash -Entry $Entry -FileName $name -Algorithm $meta.ExpectedAlgorithm
    }

    $declaredHash = (Get-EntryString -Entry $File -Key 'hash').Trim()
    $declaredHashFile = (Get-EntryString -Entry $File -Key 'hashFile').Trim()
    $hasChecksum = $declaredHash -or $declaredHashFile

    # 包内取版主包及已知跨源的文件须有来源依据；旧离线套件仍按通常的完整性规则读取。
    $sameOrigin = $meta.ManifestOrigin -and $meta.ManifestOrigin -ceq $ManifestOrigin
    $verifyOrigin = -not $sameOrigin -and ($meta.ManifestOrigin -or (-not $Offline -and ($FreshMain -or $declaredHash -or ($declaredHashFile -and $CanCheckRemote))))
    if ($verifyOrigin) {
        if (-not $hasChecksum) {
            $plan['Reason'] = '缓存文件缺少当前软件源的来源记录，将重新下载'
            if ($CanCheckRemote) { Set-WinstFilePlanValidators -Plan $plan -Context $Context -Uri $url -RequireFields }
            return $plan
        }
        # 新来源的摘要须独立取得，旧来源的 HTTP 基线和校验文件指纹都不能作证。
        $meta = Get-WinstFileMeta -Entry $null -FileName $name
    }

    if ($Offline) {
        $offlineDecl = $File
        if ($Entry -and -not $verifyOrigin) {
            if ($meta.Url) { $plan['Url'] = $meta.Url }
            if ($sameOrigin) {
                if ($meta.ExpectedHash -and $meta.SourceVersion -cne $plan['FileVersion']) {
                    if ($meta.ChecksumHashFile) {
                        $offlineDecl = @{ hashFile = $meta.ChecksumHashFile; hashFrom = $meta.ChecksumHashFrom }
                    } else { $offlineDecl = @{ hash = $meta.ExpectedHash } }
                }
                $plan['FileVersion'] = $meta.SourceVersion
            }
        }
        if (-not $hasChecksum) {
            $plan['NeedDownload'] = $false
            $plan['Reason'] = '已缓存（离线模式不做新鲜度确认）'
            return $plan
        }
        $offlineExpected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $offlineDecl -Offline `
            -CachedMeta $meta -FileUrl ([string]$plan['Url']) -FileVersion ([string]$plan['FileVersion'])
        if (-not $offlineExpected.Ok) {
            $plan['Reason'] = '离线缓存缺少可验证的校验信息'
            $plan['Hint'] = [string]$offlineExpected.Error
            return $plan
        }
        Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target -Expected $offlineExpected
        return $plan
    }

    # compare 显式含 checksum：强制重取远端校验文件（不复用索引里的指纹缓存）。
    # 地址固定的 hashFile（不随版本变化）只靠指纹永远判不出远端换了文件，需要清单显式开启这一次请求。
    $compareInfo = Get-WinstFileCompareCriteria -Text ([string]$plan['Compare'])
    $wantChecksum = (@($compareInfo.Criteria) -contains 'checksum')
    # 解析锁里的未变结论只适用于当时比对的主包；另一来源可以覆盖同名文件。
    $reuseVersion = -not $verifyOrigin -and $FileIndex -eq 0 -and $UnchangedMainHash -and -not $refresh.Raw
    if ($reuseVersion -and -not $hasChecksum -and -not $plan['IndexHash']) {
        $plan['IndexHash'] = Get-WinstPackageFileHash -Path $target
    }
    if ($reuseVersion -and ($plan['IndexHash'] -or -not $hasChecksum)) {
        $reuseVersion = $UnchangedMainHash -ieq $plan['IndexHash']
        if (-not $reuseVersion -and -not $hasChecksum) {
            $plan['Reason'] = '缓存主包与软件源上次确认的文件不同，将重新下载'
            return $plan
        }
    }
    if ($wantChecksum -and -not $hasChecksum) {
        $plan['Notice'] = ('软件源里的 compare 含 checksum，但这个文件没有声明 hash / hashFile，已按其余判据（{0}）处理' -f [string]$plan['Compare'])
    }
    # 响应头摘要已随来源解析，直接按摘要及显式比较项判断，允许下载地址变化。
    if (Get-EntryString -Entry $File -Key 'hashHeader') {
        if (-not $declaredHash) { throw '响应头摘要尚未解析，不能验证本地包' }
        $reuseVersion = $true
    }
    # 解析锁已经按清单判据确认过这个主包。声明了摘要时仍走完整性校验。
    if (-not $RequireCurrent -and $reuseVersion -and -not $hasChecksum -and $compareInfo.IsDefault) {
        $plan['NeedDownload'] = $false
        $plan['Reason'] = '已缓存且软件源已确认主包未变化'
        return $plan
    }
    if (-not $reuseVersion -and $compareInfo.IsDefault) {
        if (Test-WinstFileVersionPriorBranch -Plan $plan -Meta $meta -FileIndex $FileIndex `
                -FreshMain:$FreshMain -RefreshRaw ([string]$refresh.Raw)) {
            if ($plan['NeedDownload'] -or (-not $RequireCurrent -and -not $hasChecksum)) { return $plan }
            $reuseVersion = $true
        }
    }
    if (-not $reuseVersion -and (Test-WinstFileAddressBranch -Plan $plan -Meta $meta -Url $url)) { return $plan }
    if (-not $RequireCurrent -and -not $reuseVersion -and -not $verifyOrigin -and (Test-WinstFileFreshMainBranch -Plan $plan -Context $Context -Uri $url `
            -RefreshRaw ([string]$refresh.Raw) -CanCheckRemote:$CanCheckRemote `
            -FreshMain:$FreshMain -Reason $FreshMainReason)) {
        return $plan
    }

    # 只读视图和预览只使用匹配的缓存摘要，不触发校验文件网络请求。
    $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $File -Offline:(-not $CanCheckRemote) `
        -CachedMeta $meta -FileUrl $url -FileVersion ([string]$plan['FileVersion']) -IgnoreCachedHash:(($RequireCurrent -or $verifyOrigin -or $wantChecksum) -and $CanCheckRemote)
    if (-not $expected.Ok) {
        # 无法取得声明的校验信息时，缓存不能被视为已验证；交给下载 / 校验阶段明确报错。
        $plan['NeedDownload'] = $true
        $plan['ValidationError'] = [string]$expected.Error
        $plan['ValidationNetwork'] = Get-EntryBool -Entry $expected -Key 'Network'
        $plan['Reason'] = '无法验证缓存的完整性'
        $plan['Hint'] = [string]$expected.Error
        return $plan
    }
    if ($expected.Skipped) {
        # 制作完整套件时，必须核对远端，确认不了便重新取包。
        if ($RequireCurrent -and $refresh.Mode -ne 'always') { $refresh.Mode = 'check' }
        Set-WinstFileRefreshDecision -Criteria $compareInfo.Criteria -Plan $plan -Context $Context -Meta $meta -Refresh $refresh `
            -Name $name -Target $target -CanCheckRemote:$CanCheckRemote
        return $plan
    }

    # ③ 已声明校验 → 比对校验码
    Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target -Expected $expected
    if (-not $plan['NeedDownload'] -and $CanCheckRemote -and -not $compareInfo.IsDefault -and
            @($compareInfo.Criteria | Where-Object { $_ -ne 'checksum' }).Count -gt 0) {
        Set-WinstFileValidatorDecision -Criteria $compareInfo.Criteria -Plan $plan -Context $Context -Meta $meta -Refresh $refresh `
            -Name $name -Target $target -HasLastChecked:$false -AgeHours 0 -ChecksumVerified
    }
    return $plan
}
