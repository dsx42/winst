#Requires -Version 5.1

function Resolve-WinstGithubSourceForTag {
    <#
    .SYNOPSIS
        按发布 tag 解析 github 源（②版本号来源 ③逐文件落地 ④文件名取版本）。
    .DESCRIPTION
        Resolve-GithubSource 的「单个 tag」步骤：定版本 → 逐文件落地 → 需要时从文件名取版本。
    .OUTPUTS
        @{ Ok; Error; Files; ResultVersion }
    #>
    param(
        [hashtable]$Context,
        $Source,
        $Entry,
        [string]$Repo,
        [string]$Tag,
        $Releases,
        $Result,
        [string]$ReleaseTagPrefix = ''
    )

    $out = @{ Ok = $false; Error = ''; Files = @(); ResultVersion = '' }

    # 声明 releaseTag 前缀时先去前缀，再按 8.5 规范化（去 v 前缀），使 {version} 可直接用于 URL 模板
    $version = Get-WinstGithubTagVersion -Tag $Tag -ReleaseTagPrefix $ReleaseTagPrefix
    if (-not $version) {
        $out.Error = ('{0} 的发布版本号为空，无法确定版本' -f $Repo)
        return $out
    }

    $versionInfo = Resolve-WinstGithubVersion -Context $Context -Source $Source -Entry $Entry -Repo $Repo `
        -ChosenTag $Tag -Releases $Releases -Version $version
    if ($versionInfo.Error) {
        $out.Error = [string]$versionInfo.Error
        return $out
    }
    $version = [string]$versionInfo.Version
    $out.ResultVersion = [string]$versionInfo.ResultVersion
    $versionFrom = [string]$versionInfo.VersionFrom
    $versionKind = [string]$versionInfo.VersionKind
    $versionBetween = @($versionInfo.VersionBetween)

    $declared = @(Get-SourceFileDeclarations -Source $Source)
    if ($declared.Count -eq 0) {
        $out.Error = '软件源里没有填写要下载的文件（source.files）'
        return $out
    }

    $filesResult = New-WinstGithubResolvedFiles -Context $Context -Source $Source -Declared $declared -Repo $Repo `
        -ChosenTag $Tag -Version $version -Result $Result
    if ($filesResult.Error) {
        $out.Error = [string]$filesResult.Error
        return $out
    }
    $files = @($filesResult.Files)

    # ④ 版本号取自下载文件名（versionFrom: file）：真实版本在主包文件名里，识别不出即报错
    if ($versionFrom -eq 'file') {
        $fileVersionResult = Resolve-WinstGithubFileVersion -Files $files -ChosenTag $Tag -Version $version `
            -VersionKind $versionKind -VersionBetween $versionBetween -Result $Result
        if ($fileVersionResult.Error) {
            $out.Error = [string]$fileVersionResult.Error
            return $out
        }
        $out.ResultVersion = [string]$Result['version']
    }

    $out.Ok = $true
    $out.Files = $files
    return $out
}
