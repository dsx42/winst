#Requires -Version 5.1

function Resolve-WinstGithubVersion {
    <#
    .SYNOPSIS
        ② 版本来源：tag（默认）/ file（取自下载文件名）/ package（等取包）/ releaseTitle / releaseBody。
    .DESCRIPTION
        版本识别位置：默认 tag —— 发布 tag 就是版本；声明 file 表示
        「版本号不在 tag 里，而在下载文件名里」；声明 package 表示「发布元数据里没有版本号，等主包下载后从文件信息取」。
        releaseTitle / releaseBody 从发布元数据文本里按 versionBetween 截取（同一 release 打包多条产品线时用）。
    .OUTPUTS
        @{ Error; Version; ResultVersion; VersionFrom; VersionKind; VersionBetween }
    #>
    param([hashtable]$Context, $Source, $Entry, [string]$Repo, [string]$ChosenTag, $Releases, [string]$Version)

    $versionFrom = (Get-EntryString -Entry $Source -Key 'versionFrom').Trim().ToLowerInvariant()
    if (-not $versionFrom) { $versionFrom = 'tag' }
    if (@('tag', 'file', 'package', 'releaseTitle', 'releaseBody') -notcontains $versionFrom) {
        return @{
            Error = ('github 源的 versionFrom 只能写 tag（默认，用发布 tag 当版本号）、file（从下载文件名识别版本）、package（版本号等主包下载后从文件信息取）、releaseTitle（版本号取自发布标题）或 releaseBody（版本号取自发布正文）: {0}' -f $versionFrom)
            Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
        }
    }
    $versionKind = (Get-EntryString -Entry $Source -Key 'versionKind').Trim()
    $versionBetween = @(Get-EntryArray -Entry $Source -Key 'versionBetween')
    $resultVersion = $Version

    if ($versionFrom -eq 'file') {
        if (-not $versionKind -and $versionBetween.Count -eq 0) {
            return @{
                Error = '软件源里声明了 versionFrom: file（版本号取自下载文件名），但没有写怎么识别——请补上 versionKind 或 versionBetween'
                Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
            }
        }
    } elseif ($versionFrom -eq 'package') {
        if ($versionKind -or $versionBetween.Count -gt 0) {
            return @{
                Error = '软件源里声明了 versionFrom: package（版本号等主包下载后从文件信息取），不要再写 versionKind / versionBetween——那两个是从下载文件名识别版本的写法'
                Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
            }
        }
        # source.packageVersion：校验写法
        $packageVersionSpec = Get-WinstPackageVersionSpec -Source $Source
        if (-not $packageVersionSpec.Ok) {
            return @{ Error = [string]$packageVersionSpec.Error; Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @() }
        }
        # 版本号不在发布元数据里：置空等取包（{version} / {tag} 占位符仍按发布 tag 展开，见上）
        $resultVersion = ''
    } elseif ($versionFrom -eq 'releaseTitle' -or $versionFrom -eq 'releaseBody') {
        # 版本号取自发布元数据文本：releaseTitle = 发布标题；releaseBody = 发布正文
        if ($versionBetween.Count -eq 0) {
            return @{
                Error = ('软件源里声明了 versionFrom: {0}（版本号取自发布标题 / 正文），但没有写 versionBetween——请补上截取标记' -f $versionFrom)
                Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
            }
        }
        $kindText = $(if ($versionFrom -eq 'releaseTitle') { '标题' } else { '正文' })
        $metaSource = ''
        foreach ($item in @($Releases)) {
            if ([string]$item['Tag'] -eq $ChosenTag) {
                $metaSource = [string]$(if ($versionFrom -eq 'releaseTitle') { $item['Title'] } else { $item['Body'] })
                break
            }
        }
        if (-not $metaSource) {
            # $Releases 还没取过（releases/latest 路径不读列表）或列表里没有这条 tag → 现读一次发布列表
            try {
                foreach ($item in @(Get-GitHubReleaseListTags -Context $Context -Repo $Repo)) {
                    if ([string]$item['Tag'] -eq $ChosenTag) {
                        $metaSource = [string]$(if ($versionFrom -eq 'releaseTitle') { $item['Title'] } else { $item['Body'] })
                        break
                    }
                }
            } catch { }
        }
        if (-not $metaSource) {
            return @{
                Error = ('{0} 的发布{1}读取失败（tag {2}），无法按 {3} 识别版本' -f $Repo, $kindText, $ChosenTag, $versionFrom)
                Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
            }
        }
        $metaVersion = Get-WinstVersionFromText -Text $metaSource -Kind $versionKind -Between $versionBetween
        if (-not $metaVersion) {
            $metaPreview = $metaSource
            if ($metaPreview.Length -gt 120) { $metaPreview = $metaPreview.Substring(0, 120) + '…' }
            return @{
                Error = ('{0} 的发布{1}「{2}」里识别不出版本号——请核对 versionBetween / versionKind' -f $Repo, $kindText, $metaPreview)
                Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
            }
        }
        $resultVersion = [string]$metaVersion
        $Version = [string]$metaVersion   # 供逐文件的 {version} 展开与文件记账使用（与 tag 版本解耦）
    } elseif ($versionKind -or $versionBetween.Count -gt 0) {
        return @{
            Error = '软件源里写了 versionKind / versionBetween（从下载文件名识别版本），但没有声明 versionFrom: file；github 源默认用发布 tag 当版本号——若确实要取文件名里的版本，请补上 versionFrom: file'
            Version = ''; ResultVersion = ''; VersionFrom = ''; VersionKind = ''; VersionBetween = @()
        }
    }

    return @{
        Error = ''; Version = $Version; ResultVersion = $resultVersion
        VersionFrom = $versionFrom; VersionKind = $versionKind; VersionBetween = @($versionBetween)
    }
}
