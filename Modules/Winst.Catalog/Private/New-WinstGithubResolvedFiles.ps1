#Requires -Version 5.1

function New-WinstGithubResolvedFiles {
    <#
    .SYNOPSIS
        ③ 逐文件落地：file 通配（先取发布资产列表）或 url 模板 / 只写文件名（补全标准下载地址）。
    .DESCRIPTION
        失败分两类，调用方要区别对待：

        - `MissingFile = $true`：这个发布里**确实没有**需要的文件（`file` 通配没命中，或拼出的地址 404）。
          上游常常是先把 release 建好、再分批上传资产，因此这属于「换个发布可能就有」，
          调用方可以退回更早的发布再试。
        - `MissingFile = $false`：其它失败（读不到资产列表、版本占位符无法展开、配置写错），
          换发布也无济于事，应直接报错。
    .OUTPUTS
        @{ Error; Files; MissingFile }
    #>
    param([hashtable]$Context, $Source, $Declared, [string]$Repo, [string]$ChosenTag, [string]$Version, $Result)

    $skipCheck = Get-EntryBool -Entry $Source -Key 'skipExistsCheck'
    $assetNames = $null   # 懒加载：只有需要按文件名匹配时才抓取该发布的资产列表
    $files = @()
    $index = 0

    foreach ($item in @($Declared)) {
        $index++
        $locator = Get-SourceFileLocator -Item $item -Kind 'github'
        if ($locator.Error) { return @{ Error = [string]$locator.Error; Files = $files; MissingFile = $false } }

        $dest = Get-WinstFileDest -Item $item -Index $index -Result $Result
        $nameOverride = Get-EntryString -Entry $item -Key 'name'

        # ② 文件名匹配规则（file，通配写法）：抓取该发布的文件列表后匹配
        if ($locator.File) {
            $fileVersion = Get-WinstCompanionFileVersion -Context $Context -Item $item -Source $Source -MainVersion $Version
            if (-not $fileVersion.Ok) { return @{ Error = [string]$fileVersion.Error; Files = $files; MissingFile = $false } }
            foreach ($listedNote in @($fileVersion.Notes)) { $Result.Notes += [string]$listedNote }

            $rule = New-MatchRule -Rule (Get-MatchRuleText -Rule $locator.File -Version $fileVersion.Version -Tag $ChosenTag) -Kind '文件名'
            if (-not $rule.Ok) { return @{ Error = [string]$rule.Error; Files = $files; MissingFile = $false } }

            if ($null -eq $assetNames) {
                $assets = Get-GitHubReleaseAssets -Context $Context -Repo $Repo -Tag $ChosenTag
                if (-not $assets.Ok) {
                    return @{ Error = ('无法读取 {0} 的 {1} 这个发布里包含哪些文件（GitHub 页面结构可能已变化）' -f $Repo, $ChosenTag); Files = $files; MissingFile = $false }
                }
                $assetNames = @($assets.Names)
            }
            # 这个发布还没有上传任何资产（上游刚建好 release 时的常见状态）：换个发布可能就有
            if ($assetNames.Count -eq 0) {
                return @{
                    Error       = ('{0} 的最新版本 {1} 里还没有上传任何文件（可能还在上传，稍后刷新重试）' -f $Repo, $ChosenTag)
                    Files       = $files
                    MissingFile = $true
                }
            }

            $matched = @()
            foreach ($assetName in $assetNames) {
                if (Test-CompiledMatchRule -Rule $rule -Text $assetName) { $matched += $assetName }
            }
            if ($matched.Count -eq 0) {
                # 只提示「这个发布里还没有这个包」：不把该发布包含的上百个文件名一并拼进报错，
                # 否则界面上会刷屏（上游分批上传时尤甚）。
                return @{
                    Error       = ('{0} 的最新版本 {1} 里还没有符合「{2}」的安装包（可能还在上传，稍后刷新重试）' -f `
                            $Repo, $ChosenTag, $rule.Source)
                    Files       = $files
                    MissingFile = $true
                }
            }
            if ($matched.Count -gt 1) {
                $Result.Notes += ('有 {0} 个文件符合「{1}」，已取第一个' -f $matched.Count, $rule.Source)
            }

            $assetName = $matched[0]
            $url = Expand-GitHubFileUrl -Repo $Repo -Tag $ChosenTag -FileName $assetName
            $files += New-ResolvedFileFromDeclaration -Item $item -Url $url -Version $fileVersion.Version -Name $assetName -Dest $dest
            continue
        }

        # ③ 地址分支：完整地址模板，或只写文件名（由 winst 补全该发布的标准下载地址，省一次「取文件列表」请求）
        if (-not $locator.Url) {
            return @{ Error = '软件源里的下载文件要填写 url（地址或文件名，如 "rufus-{version}.exe"）或 file（文件名通配，如 "7z*-x64.exe"）'; Files = $files; MissingFile = $false }
        }
        $fileVersion = Get-SourceFileVersion -Item $item -Version $Version
        if (-not $fileVersion.Ok) { return @{ Error = [string]$fileVersion.Error; Files = $files; MissingFile = $false } }

        $url = Expand-ReleaseTagPlaceholder -Text (Expand-VersionPlaceholder -Text $locator.Url -Version $fileVersion.Version) -Tag $ChosenTag
        if ($url -match '\{(versionMajor|version|tag)\}') {
            return @{ Error = ('下载地址里的占位符无法替换: {0}' -f $locator.Url); Files = $files; MissingFile = $false }
        }
        if (-not (Test-UrlText -Text $url)) {
            $url = Expand-GitHubFileUrl -Repo $Repo -Tag $ChosenTag -FileName $url
        }

        # 404 时只说明「这个发布里没有该文件」：不把该发布包含的上百个文件名一并拼进报错
        # （那还要再抓一次资产列表），否则界面上会刷屏。
        $urlProbe = Test-WinstManifestUrlOrNote -Context $Context -Url $url -Skip $skipCheck -MissingError {
            ('最新版本 {0} 里还没有这个文件（可能还在上传，稍后刷新重试）: {1}；请检查文件名或地址模板是否写错' -f $ChosenTag, $url)
        }
        if (-not $urlProbe.Ok) {
            # 只有「清单只写了文件名、地址由 winst 拼成」时 404 才可能是「这个发布还没上传这个文件」，
            # 换个发布也许就有；清单自己写了完整地址模板时 404 更可能是模板写错，
            # 退回旧版本只会掩盖真正的配置问题。
            $locatorWasFileName = -not (Test-UrlText -Text $locator.Url)
            return @{ Error = [string]$urlProbe.Error; Files = $files; MissingFile = $locatorWasFileName }
        }
        if ($urlProbe.Note) { $Result.Notes += [string]$urlProbe.Note }

        $files += New-ResolvedFileFromDeclaration -Item $item -Url $url -Version $fileVersion.Version -Name $nameOverride -Dest $dest
    }

    return @{ Error = ''; Files = $files; MissingFile = $false }
}
