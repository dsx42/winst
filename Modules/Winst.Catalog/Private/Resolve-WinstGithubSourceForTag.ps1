#Requires -Version 5.1

function Resolve-WinstGithubSourceForTag {
    <#
    .SYNOPSIS
        按发布 tag 解析 github 源（②版本号来源 ③逐文件落地 ④文件名取版本）。
    .DESCRIPTION
        Resolve-GithubSource 的「单个 tag」步骤：定版本 → 逐文件落地 → 需要时从文件名取版本。

        `MissingFile = $true` 表示「这个发布里还没有要的文件」（上游常常先建 release、再分批上传资产），
        调用方可以退回更早的发布再试；其它失败换发布也没用。
    .OUTPUTS
        @{ Ok; Error; Files; ResultVersion; MissingFile }
    #>
    param(
        [hashtable]$Context,
        $Source,
        $FileSpecs,
        [string]$Repo,
        [string]$Tag,
        $Releases,
        $Result,
        [string]$ReleaseTagPrefix
    )

    $out = @{ Ok = $false; Error = ''; Files = @(); ResultVersion = ''; MissingFile = $false }

    # 去掉 releaseTag 前缀并规范化版本，供地址模板中的 {version} 使用。
    $version = Get-WinstGithubTagVersion -Tag $Tag -ReleaseTagPrefix $ReleaseTagPrefix
    if (-not $version) {
        $out.Error = ('{0} 的发布版本号为空，无法确定版本' -f $Repo)
        return $out
    }

    $versionInfo = Resolve-WinstGithubVersion -Context $Context -Source $Source -Repo $Repo `
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

    $filesResult = New-WinstGithubResolvedFiles -Context $Context -Source $Source -FileSpecs $FileSpecs -Repo $Repo `
        -ChosenTag $Tag -Version $version -Result $Result
    if ($filesResult.Error) {
        $out.Error = [string]$filesResult.Error
        $out.MissingFile = [bool]$filesResult.MissingFile
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
