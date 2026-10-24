#Requires -Version 5.1

function Get-WinstRemoteFreshnessHint {
    <#
    .SYNOPSIS
        发一次 HEAD 比对「远端文件」与「缓存索引里上次下载的记账」（ETag / Last-Modified / 长度），
        返回「有没有新包」的提示文本。
    .DESCRIPTION
        仅用于「无法获取最新版本号」的条目（source.versionFrom: "package"）：版本号只能取包后从文件信息
        得到，每次都会重新取包，用户无从判断这次取包值不值——用 HEAD 对比给一个参考：
          远端未变化 → 提示可以放心取消本次下载；远端已变化 → 提示有新包、建议更新；
          没有可比对的记录 / HEAD 失败 → 如实说无法判断，不猜测。
        **只提示、不影响下载流程**：取包照旧进行，下不下由用户在确认环节自己决定；
        --offline / --dry-run / 非 versionFromPackage 条目一律返回空文本（不发请求、不提示）。
        对比基线（fileMeta）是上次下载完成时写下的，正好对应「缓存里那份文件」——直到下次下载才更新。
        地址与上次不同也照比（地址常带会话性跟踪参数）；Last-Modified / 大小为主判据、ETag 兜底。
    .OUTPUTS
        @{ State; Text }   State: unchanged / changed / unknown；Text 为空表示无需提示
    #>
    param(
        [hashtable]$Context,
        [string]$PkgDir,
        [string]$Id,
        $Plan
    )

    $result = @{ State = 'unknown'; Text = '' }
    if (-not $Plan) { return $result }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) { return $result }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) { return $result }
    if (-not (Get-EntryBool -Entry $Plan -Key 'versionFromPackage')) { return $result }
    if (-not $Id) { $Id = ([string](Get-EntryString -Entry $Plan -Key 'id')).Trim() }
    if (-not $Id) { return $result }

    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) { return $result }
    $url = (Get-EntryString -Entry $files[0] -Key 'url').Trim()
    $name = (Get-EntryString -Entry $files[0] -Key 'name').Trim()
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }
    if (-not $url -or -not $name) { return $result }

    # files[].compare: "size" = 只比大小——dl.google.com 这类 Last-Modified 阶段性漂移的主机用
    $sizeOnly = ((Get-EntryString -Entry $files[0] -Key 'compare').Trim().ToLowerInvariant() -ieq 'size')

    $target = Join-Path (Join-Path $PkgDir $Id) $name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $result.Text = '远端是否有新包无法判断（本地还没下载过这个文件，本次下载后即可对比）'
        return $result
    }

    # 缓存索引里的记账 = 上次下载完成时写下的校验器基线
    $indexRead = Read-WinstCacheIndex -PkgDir $PkgDir
    $entry = $null
    if ($indexRead.Index.Contains($Id)) { $entry = $indexRead.Index[$Id] }
    $meta = Get-WinstFileMeta -Entry $entry -FileName $name
    if (-not $meta.Exists -or -not $meta.Url) {
        $result.Text = '远端是否有新包无法判断（没有可比对的下载记录，本次下载后将建立基线）'
        return $result
    }
    # 地址与上次不同**不直接放弃**：versionFromPackage 条目的地址常带每次会话都变化的跟踪参数
    # （如 dl.google.com /tag/s/ 链接里的 iid），同一份文件两次解析出的地址也会不同——「同一份文件」
    # 的判据是校验器而非地址
    if (-not $meta.ETag -and -not $meta.LastModified -and $null -eq $meta.Size) {
        $result.Text = '远端是否有新包无法判断（上次下载时服务器没有给出可比对的校验信息）'
        return $result
    }

    $validators = Get-WinstRemoteValidators -Context $Context -Uri $url
    if (-not $validators.Ok) {
        $result.Text = ('无法确认远端是否有新包（{0}）' -f [string]$validators.Error)
        return $result
    }

    # 校验器比对按可信度分级取用：Last-Modified 与大小是稳定判据——部分 CDN
    # （如 dl.google.com）同一份文件的 ETag / Last-Modified 也会阶段性漂移（可能数小时内整体更换、
    # 与版本无关），这类主机可能阶段性误报「远端已变化」，重新下载一次（基线随之重建）即恢复，
    # 或在该文件上声明 compare: "size" 只比大小；两边有任一判据可比即可下结论，什么都比不了时
    # 如实说无法判断、不猜测
    $changed = $false
    $compared = $false
    if (-not $sizeOnly -and $validators.LastModified -and $meta.LastModified) {
        $compared = $true
        if ([string]$validators.LastModified -ine [string]$meta.LastModified) { $changed = $true }
    }
    $localSize = $null
    try { $localSize = (Get-Item -LiteralPath $target -Force).Length } catch { $localSize = $null }
    if ($null -eq $localSize -and $null -ne $meta.Size) { $localSize = $meta.Size }
    if ($null -ne $validators.Size -and $null -ne $localSize) {
        $compared = $true
        if ([long]$validators.Size -ne [long]$localSize) { $changed = $true }
    }
    if (-not $compared -and -not $sizeOnly -and $validators.ETag -and $meta.ETag) {
        $compared = $true
        if ([string]$validators.ETag -ine [string]$meta.ETag) { $changed = $true }
    }
    if (-not $compared) {
        $result.Text = '远端是否有新包无法判断（远端没有给出可比对的校验信息）'
        return $result
    }

    if ($changed) {
        $result.State = 'changed'
        $result.Text = '远端文件已变化（有新包），建议更新'
    } else {
        $result.State = 'unchanged'
        $result.Text = '远端文件未变化（与上次下载一致），本次不下载也不影响使用'
    }
    return $result
}
