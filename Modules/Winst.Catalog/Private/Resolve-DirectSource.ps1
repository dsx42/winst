#Requires -Version 5.1

function Resolve-DirectSource {
    <#
    .SYNOPSIS
        解析 direct 源：版本取清单 version，下载地址由 {version} 展开得到。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'direct'
    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null

    # 版本来源：
    #   ① 清单 version —— 直接写死（下载地址可用 {version} 展开）；
    #   ② source.versionFrom: "page" —— 从官网页面**实时取**（如 WebView2 的「Select Version」下拉框：
    #      配 pageUrl + versionBetween / versionKind），地址仍是固定地址、不参与占位符展开；
    #   ③ source.versionFrom: "package" —— 版本号等主包下载后从文件信息取（页面也取不到版本时）。
    $version = Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')
    if (-not $version) {
        $versionFrom = (Get-EntryString -Entry $source -Key 'versionFrom').Trim().ToLowerInvariant()
        if ($versionFrom -eq 'page') {
            $pageUrl = (Get-EntryString -Entry $source -Key 'pageUrl').Trim()
            $page = Get-SourcePageHtml -Context $Context -Source $source -PageUrl $pageUrl -Label '版本页'
            if (-not $page.Ok) {
                $result.Error = $page.Error
                return $result
            }
            if ($page.Notes.Count -gt 0) { $result.Notes += $page.Notes }
            $found = Get-VersionFromSourceText -Source $source -Text ([string]$page.Html)
            if (-not $found.Ok) {
                $result.Error = ('无法从版本页 {0} 上识别出版本号（{1}）；可能是页面结构变更，需要更新软件源' -f $pageUrl, $found.Error)
                return $result
            }
            $version = [string]$found.Version
        } elseif ($versionFrom -and $versionFrom -ne 'package') {
            $result.Error = ('不认识的版本来源「{0}」（source.versionFrom）；固定地址来源可用 page（从官网页面实时取版本）' -f $versionFrom)
            return $result
        }
    }
    if (-not $version -and -not (Test-EntryVersionFromPackage -Entry $Entry)) {
        $result.Error = '这个软件用的是固定下载地址，但软件源里没有版本号：可填 version，或声明 source.versionFrom: "page" + source.pageUrl（从官网页面实时取版本，可配 versionBetween / versionKind），也可以声明 source.versionFrom: "package"（版本号等主包下载后从文件信息取）'
        return $result
    }
    # source.packageVersion：校验写法并确认它只配合 versionFrom: "package" 使用
    $packageVersionSpec = Get-WinstPackageVersionSpec -Source $source
    if (-not $packageVersionSpec.Ok) { $result.Error = $packageVersionSpec.Error; return $result }
    if ($packageVersionSpec.Spec -and -not (Test-EntryVersionFromPackage -Entry $Entry)) {
        $result.Error = 'source.packageVersion（包内版本派生规格）只配合 source.versionFrom: "package" 使用'
        return $result
    }
    $result.Version = $version
    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) {
        $result.Error = '软件源里没有填写安装包地址'
        return $result
    }

    $files = @()
    $index = 0
    foreach ($item in $declared) {
        $index++
        $locator = Get-SourceFileLocator -Item $item -Kind 'direct'
        if ($locator.Error) { $result.Error = $locator.Error; return $result }
        if (-not $locator.Url) {
            if ($locator.File) {
                $result.Error = '固定下载地址的软件要填写完整地址（url）；只有文件名通配（file）不足以定位安装包'
            } else {
                $result.Error = '软件源里的安装包地址为空'
            }
            return $result
        }

        $fileVersion = Get-SourceFileVersion -Item $item -Version $version
        if (-not $fileVersion.Ok) { $result.Error = $fileVersion.Error; return $result }

        $rawUrl = $locator.Url
        $url = Expand-VersionPlaceholder -Text $rawUrl -Version $fileVersion.Version
        if ($url -match '\{version(Major)?(_)?\}') {
            $result.Error = ('下载地址里的版本号无法替换: {0}' -f $rawUrl)
            return $result
        }

        $dest = Get-WinstFileDest -Item $item -Index $index -Result $result
        $files += New-ResolvedFileFromDeclaration -Item $item -Url $url -Version $fileVersion.Version -Dest $dest
    }

    # 主包地址由清单的版本号 + 地址模板拼出，探测一次即可发现清单里写错的版本号或模板
    $skipCheck = Get-EntryBool -Entry $source -Key 'skipExistsCheck'
    $probe = Test-WinstManifestUrlOrNote -Context $Context -Url ([string]$files[0]['url']) -Skip $skipCheck `
        -MissingError ('软件源里的下载地址不存在（HTTP 404）: {0}；请检查版本号或地址模板是否写错' -f $files[0]['url'])
    if (-not $probe.Ok) { $result.Error = [string]$probe.Error; return $result }
    if ($probe.Note) { $result.Notes += [string]$probe.Note }

    $result.Ok = $true
    $result.Files = $files
    return $result
}
