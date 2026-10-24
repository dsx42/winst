#Requires -Version 5.1

function Update-WinstLockAfterDownload {
    <#
    .SYNOPSIS
        versionFromPackage 条目的主包（重新）下载并安装成功后，把解析锁里的远端新鲜度结论改写为
        unchanged、版本对齐为本次读数。
    .DESCRIPTION
        解析锁的 remoteFresh 是**刷新时刻**的快照（HEAD 比对「远端 vs 当时缓存」的结论）——用户随后
        真的更新了软件，锁里的「远端有新包」也不会自己消失，「已装软件 / 检查更新」在下次刷新前会一直
        显示下载前的旧结论。下载成功意味着缓存里这份就是远端当前这份：remoteFresh → unchanged、
        version → 本次读数、versionFromCache → false（读数已由下载的包核实，不是「仅展示用」）。
        只改写锁里该软件的条目；锁里没有（来源不同步等）时静默跳过，下次刷新自然重建。
    #>
    param(
        [hashtable]$Context,
        [string]$SourceName,
        [string]$Id,
        [string]$Version
    )

    if (-not $SourceName -or -not $Id -or -not $Version) { return }
    $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $SourceName
    if (-not $meta -or -not $meta.HasApps) { return }

    $changed = $false
    foreach ($app in @($meta.Apps)) {
        $p = $app.PSObject.Properties['id']
        if (-not $p -or (([string]$p.Value).Trim() -ine $Id)) { continue }

        $rf = $app.PSObject.Properties['remoteFresh']
        if ($rf) { $rf.Value = 'unchanged' } else { $app | Add-Member -NotePropertyName remoteFresh -NotePropertyValue 'unchanged' }
        $vp = $app.PSObject.Properties['version']
        if ($vp) { $vp.Value = [string]$Version } else { $app | Add-Member -NotePropertyName version -NotePropertyValue ([string]$Version) }
        $vc = $app.PSObject.Properties['versionFromCache']
        if ($vc) { $vc.Value = $false } else { $app | Add-Member -NotePropertyName versionFromCache -NotePropertyValue $false }
        $changed = $true
    }
    if (-not $changed) { return }

    Write-ManifestMeta -PkgDir $Context.PkgDir -Name $SourceName -Url $meta.Url -Version $meta.Version `
        -FetchedAt $meta.FetchedAt -ResolvedAt $meta.ResolvedAt -Apps $meta.Apps
}
