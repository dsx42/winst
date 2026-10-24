#Requires -Version 5.1

function Resolve-GithubSource {
    <#
    .SYNOPSIS
        解析 github 源：走网页通道 —— 取发布 tag，必要时取该发布的文件列表。
    .DESCRIPTION
        不使用 api.github.com（匿名配额按出口 IP 计、多机共享，且可能被网络策略拦截）：
          1. https://github.com/<repo>/releases.atom                      → 发布 tag（含预发布，最新在前）
          2. files[] 的两种写法：
             · url  —— 完整地址模板（支持 {tag} 直接拼出），或**只写文件名**（winst 补全标准下载地址）；
             · file —— 文件名通配（如 "7z*-x64.exe"），需要先取该发布的文件列表再匹配。
          3. https://github.com/<repo>/releases/download/<tag>/<文件名>   → 真实下载地址
        只写文件名 / 写完整模板时各做一次 HEAD 校验；404 即判定该发布里没有这个文件。
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
