#Requires -Version 5.1

function Get-WinstCompanionFileVersion {
    <#
    .SYNOPSIS
        解析单个文件（配套文件为主）的版本：声明了 versionListUrl 时从「版本列表页」独立取最新版；
        未声明时沿用主包版本。
    .DESCRIPTION
        翻译包 / 主题这类配套文件的发版节奏常与主包不同步（经常落后）：跟着主包版本拼地址，主包先
        更新时该文件地址就会 404。声明 files[].versionListUrl 后，该文件的 {version} 改为独立解析——
        抓列表页 → 按版本识别器收集候选（优先从「以列表页路径开头」的链接里取下一段：目录页比整页
        文本干净得多，下载计数 / 百分比之类的数字不会混进来；一条都没命中再退回整页文本）→
        versionFilter 过滤 → 从新到旧逐个校验最终地址是否真的存在（与 listing 源同一口径：目录可能
        先于文件出现，上限 8 个候选，source.skipExistsCheck 可关），第一个可用的即采用。
        解析出的版本只作用于本文件的地址展开，不影响主包版本与其它文件。
        只支持 url 模板定位的文件（github 的 file / json 的 urlKey 地址不由模板拼出，不适用）。
    .OUTPUTS
        @{ Ok; Version; Error; Notes }
    #>
    param(
        [hashtable]$Context,
        $Item,
        $Source,
        [string]$MainVersion
    )

    $notes = @()

    $listTemplate = (Get-EntryString -Entry $Item -Key 'versionListUrl').Trim()
    if (-not $listTemplate) {
        $fallback = Get-SourceFileVersion -Item $Item -Version $MainVersion
        return @{ Ok = [bool]$fallback.Ok; Version = [string]$fallback.Version; Error = [string]$fallback.Error; Notes = $notes }
    }

    $result = @{ Ok = $false; Version = ''; Error = ''; Notes = $notes }

    $locator = Get-SourceFileLocator -Item $Item
    if ($locator.Error) { $result.Error = $locator.Error; return $result }
    if (-not $locator.Url) {
        $result.Error = 'files[].versionListUrl 只支持 url 模板定位的文件（地址由 {version} 拼出）；file / urlKey 定位请改写 url，或去掉 versionListUrl 跟随主包版本'
        return $result
    }

    # 列表页地址里的占位符按主包版本展开（如 {versionMajor} 跟随主包所在的大版本目录）
    $listUrl = Expand-VersionPlaceholder -Text $listTemplate -Version $MainVersion
    if ($listUrl -match '\{(versionMajor|version)\}') {
        $result.Error = ('versionListUrl 里的版本占位符无法展开: {0}' -f $listTemplate)
        return $result
    }

    $kind = (Get-EntryString -Entry $Item -Key 'versionKind').Trim()
    if (-not $kind) { $kind = (Get-EntryString -Entry $Source -Key 'versionKind').Trim() }
    if (-not $kind) {
        $result.Error = ('声明了 files[].versionListUrl 时要写版本识别器（versionKind，本文件或 source 层均可）：可用 {0}' -f ((Get-VersionKindList) -join '、'))
        return $result
    }
    $kindError = Get-WinstVersionKindError -Kind $kind
    if ($kindError) { $result.Error = $kindError; return $result }

    try {
        $html = [string](Invoke-WinstHttpGet -Uri $listUrl -Context $Context)
    } catch {
        $result.Error = ('无法打开版本列表页 {0}：{1}' -f $listUrl, $_.Exception.Message)
        return $result
    }

    # 候选收集：优先锚定列表页路径——href 以列表页路径开头时取紧随其后的路径段
    $candidates = @()
    $basePath = ''
    $pathMatch = [regex]::Match($listUrl, '^[a-z][a-z0-9+.\-]*://[^/]+(/.*)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($pathMatch.Success) { $basePath = $pathMatch.Groups[1].Value.TrimEnd('/') }
    if ($basePath) {
        foreach ($href in @(Get-RegexCaptureValues -Text $html -Pattern 'href="([^"]*)"')) {
            if (-not $href) { continue }
            if (-not $href.StartsWith($basePath, [StringComparison]::OrdinalIgnoreCase)) { continue }
            $rest = $href.Substring($basePath.Length)
            if (-not $rest.StartsWith('/')) { continue }
            $seg = ($rest.TrimStart('/').Split('/'))[0]
            if (-not $seg) { continue }
            $v = Get-VersionValue -Text $seg -Kind $kind
            if ($v -and ($candidates -notcontains $v)) { $candidates += $v }
        }
    }
    if ($candidates.Count -eq 0) {
        foreach ($candidate in @(Get-VersionCandidates -Text $html -Kind $kind)) {
            if ($candidates -notcontains $candidate) { $candidates += $candidate }
        }
    }

    $filterText = (Get-EntryString -Entry $Item -Key 'versionFilter').Trim()
    if ($filterText) {
        $filterRule = New-MatchRule -Rule $filterText -Kind '版本过滤'
        if (-not $filterRule.Ok) { $result.Error = $filterRule.Error; return $result }
        $filtered = @()
        foreach ($candidate in $candidates) {
            if (Test-CompiledMatchRule -Rule $filterRule -Text $candidate) { $filtered += $candidate }
        }
        $candidates = $filtered
    }

    if ($candidates.Count -eq 0) {
        $result.Error = ('在版本列表页 {0} 上没有找到任何版本号；可能是页面结构变更或版本识别器不合适，需要更新软件源' -f $listUrl)
        return $result
    }

    # 从新到旧逐个校验最终地址（目录可能先于文件出现，与 listing 源同一口径）
    $ordered = @(Sort-VersionList -Versions $candidates)
    $skipCheck = Get-EntryBool -Entry $Source -Key 'skipExistsCheck'
    $probed = 0
    foreach ($candidate in $ordered) {
        if ($probed -ge 8) { break }
        $fileVersion = Get-SourceFileVersion -Item $Item -Version $candidate
        if (-not $fileVersion.Ok) { $result.Error = $fileVersion.Error; return $result }
        $probed++
        if ($skipCheck) {
            $result.Ok = $true
            $result.Version = $fileVersion.Version
            return $result
        }
        $probeUrl = Expand-VersionPlaceholder -Text $locator.Url -Version $fileVersion.Version
        # FinalUriMustContain：SourceForge 这类站点对不存在的文件不回 404，而是重定向回文件根目录
        # 返回 200 HTML——校验最终地址仍带着本候选的版本段，才能可靠地退到下一个候选
        $probe = Test-RemoteFileExists -Uri $probeUrl -Context $Context -FinalUriMustContain $fileVersion.Version
        if ($null -eq $probe) {
            $notes += ('未能确认 {0} 的安装包是否可以下载（服务器未回应校验请求），已按该版本采用。' -f $fileVersion.Version)
            $result.Ok = $true
            $result.Version = $fileVersion.Version
            return $result
        }
        if ($probe) {
            if ($ordered[0] -ine $fileVersion.Version) {
                $notes += ('版本列表页上最新的 {0} 还没有可用的安装包，已改用 {1}。' -f $ordered[0], $fileVersion.Version)
            }
            $result.Ok = $true
            $result.Version = $fileVersion.Version
            return $result
        }
    }
    $result.Error = ('版本列表页 {0} 上校验过的 {1} 个候选（如 {2}）都没有可用的安装包地址；可能是附加包尚未发布，或地址模板写错' -f $listUrl, $probed, (@($ordered | Select-Object -First 3) -join '、'))
    return $result
}
