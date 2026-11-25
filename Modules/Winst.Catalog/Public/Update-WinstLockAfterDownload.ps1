#Requires -Version 5.1

function Update-WinstLockAfterDownload {
    <#
    .SYNOPSIS
        主包下载后在对应解析锁中更新远端比较结果和主包摘要。
    .DESCRIPTION
        只改写锁里该软件的条目；锁里没有（来源不同步等）时静默跳过，下次刷新自然重建。
    #>
    param(
        [hashtable]$Context,
        [string]$SourceName,
        $Plan,
        $DownloadedMain
    )

    $id = Get-EntryString -Entry $Plan -Key 'id'
    if (-not $SourceName -or -not $id -or -not $DownloadedMain) { return }
    $meta = Read-ManifestMeta -PkgDir $Context.PkgDir -Name $SourceName
    if (-not $meta -or -not $meta.HasApps) { return }

    $files = Get-EntryValue -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files'
    $changed = $false
    $apps = @()
    foreach ($app in @($meta.Apps)) {
        if ((Get-EntryString -Entry $app -Key 'id') -cne $id -or
                -not (Get-EntryBool -Entry $app -Key 'versionFromPackage') -or
                -not (Test-WinstJsonValueEqual -Left (Get-EntryValue -Entry (Get-EntryValue -Entry $app -Key 'download') -Key 'files') -Right $files)) {
            $apps += $app
            continue
        }
        $copy = Copy-WinstObjectShallow -InputObject $app
        $hash = [string]$DownloadedMain['IndexHash']
        $fresh = 'unknown'
        if ($hash) { $fresh = 'unchanged' }
        Set-EntryValue -Entry $copy -Key 'remoteFresh' -Value $fresh
        Set-EntryValue -Entry $copy -Key 'remoteFreshHash' -Value $hash
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
