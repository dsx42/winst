#Requires -Version 5.1

function Update-WinstLockAfterDownload {
    <#
    .SYNOPSIS
        在对应解析锁中登记已确认的包内版本，主包发布后同步远端比较摘要。
    .DESCRIPTION
        只改写锁里该软件的条目；锁里没有（来源不同步等）时静默跳过，下次刷新自然重建。
    #>
    param(
        [hashtable]$Context,
        [string]$SourceName,
        $Plan,
        [string]$Version,
        $DownloadedMain
    )

    $id = Get-EntryString -Entry $Plan -Key 'id'
    if (-not $SourceName -or -not $id -or -not $Version) { return }
    $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $SourceName
    if (-not $meta -or -not $meta.HasApps) { return }

    $files = Get-EntryValue -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files'
    $versionRule = Get-WinstPackageVersionRule -Plan $Plan
    $changed = $false
    $apps = @()
    foreach ($app in @($meta.Apps)) {
        if ((Get-EntryString -Entry $app -Key 'id') -cne $id -or
                -not (Get-EntryBool -Entry $app -Key 'versionFromPackage') -or
                -not (Test-WinstJsonValueEqual -Left (Get-EntryValue -Entry (Get-EntryValue -Entry $app -Key 'download') -Key 'files') -Right $files) -or
                -not (Test-WinstJsonValueEqual -Left (Get-WinstPackageVersionRule -Plan $app) -Right $versionRule)) {
            $apps += $app
            continue
        }
        $copy = Copy-WinstObjectShallow -InputObject $app
        if ($DownloadedMain) {
            $hash = [string]$DownloadedMain['IndexHash']
            $fresh = 'unknown'
            if ($hash) { $fresh = 'unchanged' }
            $null = Set-EntryValue -Entry $copy -Key 'remoteFresh' -Value $fresh
            $null = Set-EntryValue -Entry $copy -Key 'remoteFreshHash' -Value $hash
        }
        $null = Set-EntryValue -Entry $copy -Key 'version' -Value ([string]$Version)
        $null = Set-EntryValue -Entry $copy -Key 'versionFromCache' -Value $true
        $apps += $copy
        $changed = $true
    }
    if (-not $changed) { return }

    try {
        Write-ManifestMeta -PkgDir $Context.PkgDir -Name $SourceName -Url $meta.Url -Version $meta.Version `
            -FetchedAt $meta.FetchedAt -ResolvedAt $meta.ResolvedAt -Apps $apps
    } catch {
        $path = Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $SourceName
        $copy = Copy-WinstObjectShallow -InputObject $meta
        $copy['Apps'] = $apps
        (Get-WinstState -Name WinstManifestSessionMeta)[$path] = $copy
        (Get-WinstState -Name WinstManifestPersistUnavailable)[$path] = $true
        Reset-WinstCatalogCache
        Write-Host ('    提示: 下载后的解析锁未能写盘，本次更新仅在当前会话生效：{0}' -f $_.Exception.Message) -ForegroundColor Yellow
    }
}
