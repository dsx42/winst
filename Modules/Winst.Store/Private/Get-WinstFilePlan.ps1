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
        [string]$FreshMainReason = '',
        [switch]$DownloadOnly,
        [string]$SourceVersion = ''
    )

    $url = Get-EntryString -Entry $File -Key 'url'
    $name = Get-EntryString -Entry $File -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }

    # name 会被直接拼进缓存目录（<pkgDir>\<id>\<name>）：只允许单个文件名，
    # 带分隔符 / .. / 非法字符的名字会写到缓存目录之外（含由 URL 派生的名字，同样要校验）
    $name = ([string]$name).Trim()
    if ($name -and -not (Test-WinstSafePathSegment -Name $name)) { $name = '' }

    $plan = New-WinstFilePlanEntry -File $File -Url $url -Name $name

    if (-not $name -or -not $url) {
        $plan['Reason'] = '下载信息不完整（文件名不合法或地址为空）'
        return $plan
    }
    $target = Join-WinstPath $Dir $name
    $plan['Target'] = $target

    $refresh = Get-WinstFileRefreshMode -FileDecl $File
    $plan['Refresh'] = $refresh.Mode
    $plan['RefreshMaxAgeHours'] = $refresh.MaxAgeHours
    if ($refresh.Invalid) {
        $plan['Notice'] = ('软件源里的 refresh 取值「{0}」无法识别，已按 auto 处理' -f $refresh.Raw)
    }

    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Set-WinstFileMissingPlan -Plan $plan -Context $Context -Uri $url -CanCheckRemote:$CanCheckRemote
        return $plan
    }

    $meta = Get-WinstFileMeta -Entry $Entry -FileName $name
    $plan['MetaUrl'] = [string]$meta.Url
    $plan['ValidatorETag'] = [string]$meta.ETag
    $plan['ValidatorLastModified'] = [string]$meta.LastModified

    # 严格离线时，声明过完整性校验的缓存必须先验证当前字节；不能被“版本相同”等快捷分支绕过。
    $declaredHash = (Get-EntryString -Entry $File -Key 'hash').Trim()
    $declaredHashFile = (Get-EntryString -Entry $File -Key 'hashFile').Trim()
    if ($Offline -and ($declaredHash -or $declaredHashFile)) {
        $offlineExpected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $File -Offline `
            -CachedMeta $meta -FileUrl $url -SourceVersion $SourceVersion
        if (-not $offlineExpected.Ok) {
            $plan['NeedDownload'] = $true
            $plan['Reason'] = '离线缓存缺少可验证的校验信息'
            $plan['Hint'] = [string]$offlineExpected.Error
            return $plan
        }
        Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target `
            -Expected $offlineExpected -ForceRehash
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
            -FileUrl $url -SourceVersion $SourceVersion
        $hasCurrentChecksumProvenance = ([string]$meta.ChecksumFingerprint -and
            ([string]$meta.ChecksumFingerprint -ieq $currentFingerprint))
    }
    if ($hasCurrentChecksumProvenance) {
        if (Test-WinstFileVersionPriorBranch -Plan $plan -File $File -Meta $meta -FileIndex $FileIndex `
                -DownloadOnly:$DownloadOnly -RefreshRaw ([string]$refresh.Raw)) {
            return $plan
        }
    }
    if (Test-WinstFileAddressBranch -Plan $plan -Meta $meta -Url $url) { return $plan }
    if (Test-WinstFileFreshMainBranch -Plan $plan -Context $Context -Uri $url -FileIndex $FileIndex `
            -RefreshRaw ([string]$refresh.Raw) -Offline:$Offline -CanCheckRemote:$CanCheckRemote `
            -FreshMain:$FreshMain -Reason $FreshMainReason) {
        return $plan
    }

    $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $File -Offline:$Offline `
        -CachedMeta $meta -FileUrl $url -SourceVersion $SourceVersion
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
        Set-WinstFileRefreshDecision -Plan $plan -Context $Context -File $File -Meta $meta -Refresh $refresh `
            -FileIndex $FileIndex -Name $name -Target $target -Offline:$Offline -DryRun:$DryRun -CanCheckRemote:$CanCheckRemote
        return $plan
    }

    # ③ 已声明校验 → 比对校验码
    Set-WinstFileHashDecision -Plan $plan -Entry $Entry -Name $name -Target $target -Expected $expected -ForceRehash:$Offline
    return $plan
}
