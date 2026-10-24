#Requires -Version 5.1

function Add-RemoteManifest {
    <#
    .SYNOPSIS
        添加 GitHub 仓库软件源：源名自动取「用户名/仓库」，先校验清单可用再写入共享源列表。
    .DESCRIPTION
        只接受 GitHub 仓库 / 清单地址（见 Resolve-GitHubManifestInput）；源列表存于安装包位置
        （<pkgDir>\manifests\sources.json），多机共用同一安装包位置时共享。
        **添加即校验**：实际拉取清单并解析成功才写入；失败报明确原因且不写盘。
    .OUTPUTS
        @{ Success; Message; Name; Version; Apps; Resolved; ResolveFailed; Total }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$RepoOrUrl
    )

    $result = @{
        Success       = $false
        Message       = ''
        Name          = ''
        Version       = ''
        Apps          = @()
        Resolved      = 0
        ResolveFailed = 0
        Total         = 0
    }

    $parsed = Resolve-GitHubManifestInput -RepoOrUrl $RepoOrUrl
    if (-not $parsed.Ok) { $result.Message = $parsed.Error; return $result }

    $sourceName = [string]$parsed.Name
    if ($sourceName -ieq (Get-WinstOfficialManifestName)) {
        $result.Message = ('软件源 {0} 为内置源，无需添加' -f $sourceName)
        return $result
    }
    foreach ($retiredName in @(Get-WinstRetiredManifestSourceList)) {
        if ($sourceName -ieq [string]$retiredName) {
            $result.Message = ('{0} 是内置源的历史名称（内置源现为 {1}），不能作为自定义源添加' -f $sourceName, (Get-WinstOfficialManifestName))
            return $result
        }
    }
    if ($sourceName -ieq (Get-WinstLocalManifestName)) {
        $result.Message = ('{0} 是本地清单的固定名称（自动识别脚本同目录的清单文件），不能添加；把自己的清单文件放到脚本同目录即可' -f (Get-WinstLocalManifestName))
        return $result
    }
    if (Get-RemoteManifestByName -PkgDir $Context.PkgDir -Name $sourceName) {
        $result.Message = ('软件源 {0} 已存在' -f $sourceName)
        return $result
    }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) {
        $result.Message = '离线模式（--offline）下不能添加软件源，请联网后重试'
        return $result
    }

    # 添加即校验：实际拉取清单并全量解析，失败即不写入源列表
    $probe = [ordered]@{
        name      = $sourceName
        kind      = 'remote'
        url       = [string]$parsed.Url
        files     = @()
        isLocal   = $false
        isBuiltin = $false
    }
    Write-Host ('  正在校验 {0} …' -f $parsed.Url) -ForegroundColor Gray
    $check = Update-ManifestSource -Context $Context -Source $probe
    if (-not $check.Success) {
        $result.Message = ('添加失败：{0}' -f $check.Message)
        return $result
    }

    $result.Name = $sourceName
    $result.Version = [string]$check.Version
    $result.Apps = @($check.Apps)
    $result.Resolved = [int]$check.Resolved
    $result.ResolveFailed = [int]$check.ResolveFailed
    $result.Total = [int]$check.Total

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) {
        $result.Success = $true
        $result.Message = ('（预览）将添加软件源 {0}；清单可用（版本 {1}），共 {2} 个软件，可用 {3} / 有误 {4}（未保存）' -f `
            $sourceName, (Format-ManifestVersion -Version $result.Version), $result.Total, $result.Resolved, $result.ResolveFailed)
        return $result
    }

    $sources = @(Get-RemoteManifestList -PkgDir $Context.PkgDir)
    $sources += [ordered]@{ name = $sourceName; repo = $sourceName; url = [string]$parsed.Url }
    try {
        Write-ManifestSources -PkgDir $Context.PkgDir -Sources $sources
    } catch {
        # 写入源列表失败：回收本次校验写下的缓存，保持环境干净
        foreach ($path in @(
            (Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $sourceName),
            (Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $sourceName)
        )) {
            if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
        $result.Message = ('写入软件源列表失败: {0}' -f $_.Exception.Message)
        return $result
    }

    $result.Success = $true
    $result.Message = ('已添加软件源 {0}（清单版本 {1}）；共 {2} 个软件，可用 {3} / 有误 {4}' -f `
        $sourceName, (Format-ManifestVersion -Version $result.Version), $result.Total, $result.Resolved, $result.ResolveFailed)
    return $result
}
