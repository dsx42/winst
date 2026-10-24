#Requires -Version 5.1

function Ensure-OfficialManifest {
    <#
    .SYNOPSIS
        内置源自愈：缺失则插入首位、地址与内置常量不一致则覆盖并警告回写、
        清掉旧内置源留下的重复条目。
    .OUTPUTS
        [bool] 是否改动了源列表
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $sources = @(Get-RemoteManifestList -PkgDir $Context.PkgDir)
    $changed = $false

    # 先摘掉旧内置源留下的残留条目：改了内置源仓库之后，源列表里会留下一个指向旧来源的
    # 重复项，它既不是当前内置源、也不该出现在用户列表里。历史源名是保留名（用户无法自己添加），
    # 因此按名字清理不会误删用户自己的来源
    $retired = @(Get-WinstRetiredManifestSourceList)
    $retiredRemoved = @()
    if ($retired.Count -gt 0) {
        $kept = @()
        foreach ($source in $sources) {
            $name = [string]$source['name']
            $isRetired = $false
            foreach ($one in $retired) {
                if ($name -ieq [string]$one) { $isRetired = $true; break }
            }
            if ($isRetired) { $changed = $true; $retiredRemoved += $name; continue }
            $kept += $source
        }
        $sources = @($kept)
    }

    $index = -1
    for ($i = 0; $i -lt $sources.Count; $i++) {
        if ([string]$sources[$i]['name'] -ieq (Get-WinstOfficialManifestName)) { $index = $i; break }
    }

    if ($index -lt 0) {
        $sources = @([ordered]@{ name = (Get-WinstOfficialManifestName); repo = (Get-WinstOfficialManifestName); url = (Get-WinstOfficialManifestUrl) }) + $sources
        $changed = $true
    } elseif ([string]$sources[$index]['url'] -ne (Get-WinstOfficialManifestUrl)) {
        $sources[$index]['url'] = (Get-WinstOfficialManifestUrl)
        $changed = $true
        Write-Host '  警告: 内置软件源地址被修改，已恢复为内置地址。' -ForegroundColor Yellow
    } elseif ($index -gt 0) {
        # 内置源固定排在首位，便于展示与查找
        $officialEntry = $sources[$index]
        $rest = @()
        for ($i = 0; $i -lt $sources.Count; $i++) {
            if ($i -ne $index) { $rest += $sources[$i] }
        }
        $sources = @($officialEntry) + $rest
        $changed = $true
    }

    if ($changed) {
        try {
            Write-ManifestSources -PkgDir $Context.PkgDir -Sources $sources
        } catch {
            Write-Host ('  警告: 内置软件源写回失败: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    # 历史内置源的清单缓存与解析锁留着也没人再读（源列表里已经没有它），删掉以免误以为还在用旧源
    foreach ($retiredName in $retiredRemoved) {
        foreach ($path in @(
            (Get-ManifestCachePath -PkgDir $Context.PkgDir -Name $retiredName),
            (Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $retiredName)
        )) {
            if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
            }
        }
    }
    return $changed
}
