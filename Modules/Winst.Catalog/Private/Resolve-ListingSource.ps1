#Requires -Version 5.1

function Resolve-ListingSource {
    <#
    .SYNOPSIS
        解析 listing 源：抓取版本列表页，用版本识别器收集候选，按 versionFilter 过滤、sort 从高到低排序，
        逐个候选校验安装包是否真的可以下载，取第一个可用版本后展开 URL 模板。
    .DESCRIPTION
        版本列表页会提前出现尚未发布正式包的版本目录（如 python.org 的 3.15.0 目录此时只有 alpha 包），
        只取最大版本会解析出无法下载的地址；因此按「最新优先」逐个校验主包地址，第一个可用的即采用。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'listing'
    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    # indexUrl 可以写一条，也可以写成多条（如 Maven 的 maven-3/ 与 maven-4/ 两个大版本目录），
    # 各页收集到的候选版本合并后统一过滤 / 排序 / 逐个探测
    $indexUrls = @()
    foreach ($item in @(Get-EntryValue -Entry $source -Key 'indexUrl' -Default $null)) {
        if ($null -eq $item) { continue }
        $text = ([string]$item).Trim()
        if ($text) { $indexUrls += $text }
    }
    $versionKind = (Get-EntryString -Entry $source -Key 'versionKind').Trim()

    if ($indexUrls.Count -eq 0) {
        $result.Error = '软件源里没有填写版本列表页地址（source.indexUrl）'
        return $result
    }
    if (-not $versionKind) {
        $result.Error = ('没有填写版本识别器（source.versionKind）；可用 {0}，例如 python.org 这类目录页写 semver' -f ((Get-VersionKindList) -join '、'))
        return $result
    }
    $kindError = Get-WinstVersionKindError -Kind $versionKind
    if ($kindError) { $result.Error = $kindError; return $result }

    $candidates = @()
    $failedPages = @()
    foreach ($indexUrl in $indexUrls) {
        try {
            $html = Invoke-WinstHttpGet -Uri $indexUrl -Context $Context
        } catch {
            $failedPages += ('{0}（{1}）' -f $indexUrl, $_.Exception.Message)
            continue
        }
        foreach ($candidate in @(Get-VersionCandidates -Text $html -Kind $versionKind)) {
            if ($candidates -notcontains $candidate) { $candidates += $candidate }
        }
    }
    if ($candidates.Count -eq 0 -and $failedPages.Count -gt 0) {
        $result.Error = ('无法打开版本列表页 {0}；可能是网络问题，或页面结构变更、需要更新软件源' -f ($failedPages -join '；'))
        return $result
    }
    if ($failedPages.Count -gt 0) {
        $result.Notes += ('有 {0} 个版本列表页本次没能打开，已用其余页面解析' -f $failedPages.Count)
    }

    $filterRule = $null
    $versionFilter = (Get-EntryString -Entry $source -Key 'versionFilter').Trim()
    if ($versionFilter) {
        $filterRule = New-MatchRule -Rule $versionFilter -Kind '版本过滤'
        if (-not $filterRule.Ok) { $result.Error = $filterRule.Error; return $result }

        $filtered = @()
        foreach ($candidate in $candidates) {
            if (Test-CompiledMatchRule -Rule $filterRule -Text $candidate) { $filtered += $candidate }
        }
        $candidates = $filtered
    }

    if ($candidates.Count -eq 0) {
        $hint = ''
        if ($versionFilter) { $hint = ('（过滤条件「{0}」）' -f $versionFilter) }
        $result.Error = ('在版本列表页 {0} 上没有找到任何版本号{1}；可能是页面结构变更或版本识别器不合适，需要更新软件源' -f ($indexUrls -join '、'), $hint)
        return $result
    }

    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) {
        $result.Error = '软件源里没有填写安装包地址（source.files）'
        return $result
    }
    $mainLocator = Get-SourceFileLocator -Item $declared[0] -Kind 'listing'
    if ($mainLocator.Error) { $result.Error = $mainLocator.Error; return $result }
    $mainTemplate = $mainLocator.Url
    if (-not $mainTemplate) {
        $result.Error = '版本列表页来源的主包地址要写成带 {version} 的地址模板（url）'
        return $result
    }

    # 从最新到最旧逐个校验安装包是否真的存在；上限 8 个候选，避免异常页面造成大量请求
    $ordered = @(Sort-VersionList -Versions $candidates -SortMode (Get-EntryString -Entry $source -Key 'sort'))
    $skipCheck = Get-EntryBool -Entry $source -Key 'skipExistsCheck'
    $version = ''
    $tried = @()
    $probeCache = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal)
    $maxProbes = 8

    foreach ($candidate in $ordered) {
        if ($tried.Count -ge $maxProbes) { break }
        $normalized = Get-NormalizedVersionString -Value $candidate
        $mainVersion = Get-SourceFileVersion -Item $declared[0] -Version $normalized
        if (-not $mainVersion.Ok) { $result.Error = $mainVersion.Error; return $result }
        $probeUrl = Expand-VersionPlaceholder -Text $mainTemplate -Version $mainVersion.Version

        $state = 'skipped'
        if (-not $skipCheck) {
            $probe = $null
            if ($probeCache.ContainsKey($probeUrl)) {
                $probe = $probeCache[$probeUrl]
            } else {
                $probe = Test-RemoteFileExists -Uri $probeUrl -Context $Context
                $probeCache[$probeUrl] = $probe
            }
            if ($null -eq $probe) { $state = 'unknown' }
            elseif ($probe) { $state = 'ok' }
            else { $state = 'missing' }
        }

        $tried += $normalized
        if ($state -eq 'missing') { continue }

        $version = $normalized
        if ($state -eq 'unknown') {
            $result.Notes += ('未能确认 {0} 的安装包是否可以下载（服务器未回应校验请求），已按该版本记录。' -f $normalized)
        }
        break
    }

    if (-not $version) {
        $result.Error = ('版本列表页上的版本都没有可下载的安装包（已检查: {0}）；可能是安装包命名变化，需要更新软件源' -f ($tried -join '、'))
        return $result
    }

    $result.Version = $version
    if ($tried.Count -gt 1) {
        $result.Notes += ('最新的 {0} 还没有可下载的正式安装包，已改用 {1}。' -f $tried[0], $version)
    } elseif ($ordered.Count -gt 1) {
        $result.Notes += ('版本列表页共找到 {0} 个版本，已选用最新的 {1}。' -f $ordered.Count, $version)
    }

    $files = @()
    $index = 0
    foreach ($item in $declared) {
        $index++
        $locator = Get-SourceFileLocator -Item $item -Kind 'listing'
        if ($locator.Error) { $result.Error = $locator.Error; return $result }
        if (-not $locator.Url) {
            $result.Error = '版本列表页来源要填写地址模板（url），其中的 {version} 会替换成列表页上取到的最新版本'
            return $result
        }

        $dest = Get-WinstFileDest -Item $item -Index $index -Result $result
        $fileVersion = Get-WinstCompanionFileVersion -Context $Context -Item $item -Source $source -MainVersion $version
        if (-not $fileVersion.Ok) { $result.Error = $fileVersion.Error; return $result }
        foreach ($listedNote in @($fileVersion.Notes)) { $result.Notes += [string]$listedNote }
        $files += New-ResolvedFileFromDeclaration -Item $item -Version $fileVersion.Version -Dest $dest `
            -Url (Expand-VersionPlaceholder -Text $locator.Url -Version $fileVersion.Version)
    }

    $result.Ok = $true
    $result.Files = $files
    return $result
}
