#Requires -Version 5.1

function Resolve-GithubSource {
    <#
    .SYNOPSIS
        解析 github 源：走网页通道 —— 取发布 tag，必要时取该发布的文件列表。
    .DESCRIPTION
        不使用 api.github.com（匿名配额按出口 IP 计、多机共享，且可能被网络策略拦截）：
          1. https://github.com/<repo>/releases/latest 跳转（未声明 releaseTag 时）/ releases 列表页 → 发布 tag
          2. files[] 的两种写法：
             · url  —— 完整地址模板（支持 {tag} 直接拼出），或**只写文件名**（winst 补全标准下载地址）；
             · file —— 文件名通配（如 "7z*-x64.exe"），需要先取该发布的文件列表再匹配。
          3. https://github.com/<repo>/releases/download/<tag>/<文件名>   → 真实下载地址
        只写文件名 / 写完整模板时各做一次 HEAD 校验；404 即判定该发布里没有这个文件。

        **最新发布里没有需要的文件时退回更早的发布**：GitHub 上常见「release 已建好、资产还在分批上传」，
        此时 `releases/latest` 指向的发布里没有安装包，但上一次发布的文件是可用的。
        判定为「这个发布里没有要的文件」后，按版本号从新到旧逐个试，
        用第一个**确实含有该文件**的发布。回退成功时把「用的是旧发布」写进 Notes，让用户知道为什么不是最新版。

        取 tag / 定版本 / 逐文件落位各由独立函数承担。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'github'
    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $repo = (Get-EntryString -Entry $source -Key 'repo').Trim()
    if (-not $repo) {
        $result.Error = '软件源里没有填写这个软件在 GitHub 上的仓库（source.repo）'
        return $result
    }
    $result.Repo = $repo

    # ① 取发布 tag（网页通道，不消耗 API 配额）
    $releaseTagPrefix = (Get-EntryString -Entry $source -Key 'releaseTag').Trim()
    $tagResult = Get-WinstGithubTag -Context $Context -Repo $repo -ReleaseTagPrefix $releaseTagPrefix
    if ($tagResult.Error) { $result.Error = $tagResult.Error; return $result }
    foreach ($note in @($tagResult.Notes)) { $result.Notes += [string]$note }
    $chosenTag = [string]$tagResult.Tag
    $releases = @($tagResult.Releases)

    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) {
        $result.Error = '软件源里没有填写要下载的文件（source.files）'
        return $result
    }

    # ②③④ 定版本 → 逐文件落地 → 需要时从文件名取版本
    $attempt = Resolve-WinstGithubSourceForTag -Context $Context -Source $source -Entry $Entry -Repo $repo `
        -Tag $chosenTag -Releases $releases -Result $result -ReleaseTagPrefix $releaseTagPrefix

    # —— 最新发布里没有需要的文件：按版本号从新到旧退回更早的发布 ——
    # source.latestOnly: true 时不做回退（只想跟最新发布走、宁可报错等上游传完的场景）
    $latestOnly = Get-EntryBool -Entry $source -Key 'latestOnly'
    if (-not $attempt.Ok -and $attempt.MissingFile -and -not $latestOnly) {
        $firstError = [string]$attempt.Error
        $fallbackTags = @(Resolve-WinstGithubFallbackTags -Context $Context -Repo $repo -ChosenTag $chosenTag `
                -Releases $releases -ReleaseTagPrefix $releaseTagPrefix)
        # 每个候选都要再抓一次资产列表 + 逐个 HEAD 探测：只在最近几个发布里找，不做整段列表的穷举
        if ($fallbackTags.Count -gt 5) { $fallbackTags = @($fallbackTags[0..4]) }
        foreach ($fallbackTag in $fallbackTags) {
            # 每次回退都用干净的结果对象：上一条尝试的 Notes / Files 不能混进这一条
            $probe = New-SourceResolveResult -Kind 'github'
            $probe.Repo = $repo
            $retry = Resolve-WinstGithubSourceForTag -Context $Context -Source $source -Entry $Entry -Repo $repo `
                -Tag $fallbackTag -Releases $releases -Result $probe -ReleaseTagPrefix $releaseTagPrefix
            if (-not $retry.Ok) { continue }

            # 回退成功：沿用这次的结果，并把「为什么不是最新发布」说清楚
            foreach ($note in @($probe.Notes)) { $result.Notes += [string]$note }
            $result.Notes += ('最新发布 {0} 里还没有这个文件，已改用更早的发布 {1}（版本 {2}）' -f $chosenTag, $fallbackTag, [string]$retry.ResultVersion)
            $result.Ok = $true
            $result.Tag = $fallbackTag
            $result.Version = [string]$retry.ResultVersion
            $result.Files = @($retry.Files)
            return $result
        }
        # 一条都没成：报第一次（最新发布）的错误——那才是用户预期的版本，最值得说清
        $result.Error = $firstError
        return $result
    }
    if (-not $attempt.Ok) {
        $result.Error = [string]$attempt.Error
        return $result
    }

    $result.Ok = $true
    $result.Tag = $chosenTag
    $result.Version = [string]$attempt.ResultVersion
    $result.Files = @($attempt.Files)
    return $result
}
