#Requires -Version 5.1

function Get-WinstRemoteFreshnessHint {
    <#
    .SYNOPSIS
        按文件声明的 compare 判据确认 package 来源的远端新鲜度。
    .DESCRIPTION
        与下载计划共用判据解析和校验器比较。没有可比较信息时返回 unknown；
        离线、预览和非 package 来源不联网。地址变化本身不代表文件内容变化。
    .OUTPUTS
        @{ State; Text }，State 为 unchanged / changed / unknown。
    #>
    param([hashtable]$Context, [string]$PkgDir, [string]$Id, $Plan)

    $result = @{ State = 'unknown'; Text = '' }
    $options = Get-WinstState -Name WinstOptions
    if (-not $Plan -or ($options -and ($options.Offline -or $options.DryRun))) { return $result }
    if (-not (Get-EntryBool -Entry $Plan -Key 'versionFromPackage')) { return $result }
    if (-not $Id) { $Id = Get-EntryString -Entry $Plan -Key 'id' }
    if (-not $Id) { return $result }
    $files = @(Get-EntryArray -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files')
    if ($files.Count -eq 0) { return $result }
    $file = $files[0]
    $url = Get-EntryString -Entry $file -Key 'url'
    $name = Get-EntryString -Entry $file -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }
    if (-not $url -or -not (Test-WinstSafePathSegment -Name $name) -or -not (Test-WinstSafePathSegment -Name $Id)) { return $result }
    $target = Join-WinstPath (Join-WinstPath $PkgDir $Id) $name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        $result.Text = '远端是否有新包无法判断（本地还没有这个文件）'
        return $result
    }

    $indexRead = Read-WinstCacheIndex -PkgDir $PkgDir
    $entry = $null
    if ($indexRead.Index.Contains($Id)) { $entry = $indexRead.Index[$Id] }
    $meta = Get-WinstFileMeta -Entry $entry -FileName $name
    $compareInfo = Get-WinstFileCompareCriteria -Text (Get-EntryString -Entry $file -Key 'compare')
    $criteria = @($compareInfo.Criteria)
    $compared = 0
    $changed = $false
    $errors = @()
    $checksumUnavailable = $false
    $header = Get-EntryString -Entry $file -Key 'hashHeader'
    $hasDeclaredChecksum = [bool]((Get-EntryString -Entry $file -Key 'hash').Trim() -or
        (Get-EntryString -Entry $file -Key 'hashFile').Trim())

    if ($header -or $hasDeclaredChecksum) {
        try {
            $expectedHash = ''
            if ($header) {
                $expectedHash = Get-WinstRemoteHeader -Context $Context -Uri $url -Name $header
            } else {
                $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $file -CachedMeta $meta `
                    -FileUrl $url -FileVersion (Get-EntryString -Entry $file -Key 'version') `
                    -IgnoreCachedHash:($criteria -contains 'checksum')
                if (-not $expected.Ok -or $expected.Skipped) { throw '没有可用于比较的远端摘要' }
                $expectedHash = [string]$expected.Hash
            }
            $algorithm = Get-HashAlgorithmFromDigestLength -Length $expectedHash.Length
            if (-not $algorithm -or $expectedHash -notmatch '^[0-9a-fA-F]+$') { throw '远端摘要格式无效' }
            $actual = ''
            if (-not $header) {
                if ($algorithm -eq 'SHA256') { $actual = Get-WinstRecordedHash -Entry $entry -FileName $name }
                else { $actual = Get-WinstManifestHash -Entry $entry -FileName $name -Algorithm $algorithm }
            }
            if (-not $actual) { $actual = Get-WinstFileHash -Path $target -Algorithm $algorithm }
            if (-not $actual) { throw '无法读取本地安装包摘要' }
            $compared++
            if ($actual -ine $expectedHash) { $changed = $true }
        } catch { $errors += $_.Exception.Message; $checksumUnavailable = $true }
    }

    # 完整摘要默认直接判定内容；显式 HTTP 判据仍与声明摘要组合比较。
    # hashFile 默认复用匹配声明指纹的期望摘要，显式 checksum 才强制重新请求。
    $httpCriteria = @($criteria | Where-Object { $_ -ne 'checksum' })
    $evaluateHttp = (-not $header -and (-not $compareInfo.IsDefault -or -not $hasDeclaredChecksum))
    if ($evaluateHttp -and $httpCriteria.Count -gt 0 -and $meta.Exists) {
        $validators = Get-WinstRemoteValidators -Context $Context -Uri $url
        if ($validators.Ok) {
            $localSize = $null
            try { $localSize = (Get-Item -LiteralPath $target -Force -ErrorAction Stop).Length } catch { }
            # 缺少旧实体标识不能证明远端变化；提示层只比较已有基线，下载层可选择重取建基线。
            $comparableCriteria = @($httpCriteria | Where-Object {
                $_ -eq 'size' -or ($_ -eq 'etag' -and $meta.ETag) -or ($_ -eq 'lastmodified' -and $meta.LastModified)
            })
            $comparison = Compare-WinstFileValidators -Criteria $comparableCriteria -Meta $meta -Validators $validators -LocalSize $localSize
            $compared += [int]$comparison.Compared
            if ($comparison.Changed) { $changed = $true }
        } else { $errors += [string]$validators.Error }
    }
    if ($compared -eq 0 -or ($checksumUnavailable -and -not $changed)) {
        $reason = '没有可比对的校验信息'
        if ($errors.Count -gt 0) { $reason = $errors -join '；' }
        $result.Text = ('远端是否有新包无法判断（{0}）' -f $reason)
        return $result
    }
    if ($changed) {
        $result.State = 'changed'
        $result.Text = '远端文件已变化（有新包），建议更新'
    } else {
        $result.State = 'unchanged'
        $result.Text = '远端文件未变化（与上次下载一致）'
    }
    return $result
}
