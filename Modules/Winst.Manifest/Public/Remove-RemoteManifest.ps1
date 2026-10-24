#Requires -Version 5.1

function Remove-RemoteManifest {
    <#
    .SYNOPSIS
        删除在线软件源，并清理其清单缓存与 sidecar 元数据。
    .OUTPUTS
        @{ Success; Message }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Name
    )

    $result = @{ Success = $false; Message = '' }
    $sourceName = ConvertTo-WinstTrimmedInput -Value $Name

    # 软件源变化后条目（含依赖关系）可能变化：置空依赖索引，下次使用时按新清单重建
    $null = Set-WinstState -Name WinstDependencyIndex -Value ($null)

    if (-not $sourceName) { $result.Message = '请指定要删除的软件源名称'; return $result }
    if ($sourceName -ieq (Get-WinstOfficialManifestName)) {
        $result.Message = ('{0} 为内置软件源，不能删除' -f (Get-WinstOfficialManifestName))
        return $result
    }
    if ($sourceName -ieq (Get-WinstLocalManifestName)) {
        $result.Message = ('本地清单不用删除：把脚本同目录的清单文件（manifest.json / manifests\*.json）移走或改名即可')
        return $result
    }

    $sources = @(Get-RemoteManifestList -PkgDir $Context.PkgDir)
    $newList = @()
    $found = $false
    foreach ($source in $sources) {
        if ([string]$source['name'] -ieq $sourceName) { $found = $true; continue }
        $newList += $source
    }
    if (-not $found) { $result.Message = ('软件源 "{0}" 不存在' -f $sourceName); return $result }

    try {
        Write-ManifestSources -PkgDir $Context.PkgDir -Sources $newList
    } catch {
        $result.Message = ('写入软件源列表失败: {0}' -f $_.Exception.Message)
        return $result
    }

    foreach ($path in @(
        (Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $sourceName),
        (Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $sourceName)
    )) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            try { Remove-Item -LiteralPath $path -Force -ErrorAction Stop } catch {
                # 缓存清理失败不影响删除结果
            }
        }
    }

    $result.Success = $true
    $result.Message = ('已删除软件源 "{0}"' -f $sourceName)
    return $result
}
