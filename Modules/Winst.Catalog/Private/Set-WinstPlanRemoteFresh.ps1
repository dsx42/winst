#Requires -Version 5.1

function Set-WinstPlanRemoteFresh {
    <#
    .SYNOPSIS
        按清单的摘要与 HTTP 判据比较远端和缓存主包，将结论写入计划的 remoteFresh。
    #>
    param($Plan, [hashtable]$Context)

    $pkgDir = $Context.PkgDir

    $Plan['remoteFresh'] = 'unknown'
    $options = Get-WinstState -Name WinstOptions
    if (-not $PkgDir -or ($options -and ($options.Offline -or $options.DryRun))) { return }
    $id = Get-EntryString -Entry $Plan -Key 'id'
    $files = @(Get-EntryArray -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files')
    if ($files.Count -eq 0) { return }
    $file = $files[0]
    $url = Get-EntryString -Entry $file -Key 'url'
    $name = Get-EntryString -Entry $file -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }
    if (-not $url -or -not (Test-WinstSafePathSegment -Name $name) -or -not (Test-WinstSafePathSegment -Name $Id)) { return }
    $target = Join-WinstPath (Join-WinstPath $PkgDir $Id) $name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { return }

    $indexRead = Read-WinstCacheIndex -PkgDir $PkgDir -Ids @($id)
    $entry = $null
    if ($indexRead.Index.Contains($Id)) { $entry = $indexRead.Index[$Id] }
    $meta = Get-WinstFileMeta -Entry $entry -FileName $name
    $sameOrigin = $meta.ManifestOrigin -and $meta.ManifestOrigin -ceq (Get-EntryString -Entry $Plan -Key 'manifestOrigin')
    $recordedHash = Get-WinstRecordedHash -Entry $entry -FileName $name
    $compareInfo = Get-WinstFileCompareCriteria -Text (Get-EntryString -Entry $file -Key 'compare')
    $criteria = @($compareInfo.Criteria)
    $compared = 0
    $changed = $false
    $checksumUnavailable = $false
    $header = Get-EntryString -Entry $file -Key 'hashHeader'
    $hasDeclaredChecksum = [bool]((Get-EntryString -Entry $file -Key 'hash').Trim() -or
        (Get-EntryString -Entry $file -Key 'hashFile').Trim())

    if ($header -or $hasDeclaredChecksum) {
        try {
            if ($header) {
                $expectedHash = Get-WinstRemoteHeader -Context $Context -Uri $url -Name $header
            } else {
                $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $file -CachedMeta $meta `
                    -FileUrl $url -FileVersion (Get-EntryString -Entry $file -Key 'version') `
                    -IgnoreCachedHash:(-not $sameOrigin -or $criteria -contains 'checksum')
                if (-not $expected.Ok -or $expected.Skipped) { throw '没有可用于比较的远端摘要' }
                $expectedHash = [string]$expected.Hash
            }
            $algorithm = Get-HashAlgorithmFromDigestLength -Length $expectedHash.Length
            if (-not $algorithm -or $expectedHash -notmatch '^[0-9a-fA-F]+$') { throw '远端摘要格式无效' }
            if ($algorithm -eq 'SHA256') { $actual = $recordedHash }
            else { $actual = Get-WinstManifestHash -Entry $entry -FileName $name -Algorithm $algorithm }
            if (-not $actual) { $actual = Get-WinstPackageFileHash -Path $target -Algorithm $algorithm -IndexHash ([ref]$recordedHash) }
            if (-not $actual) { throw '无法读取本地安装包摘要' }
            $compared++
            if ($actual -ine $expectedHash) { $changed = $true }
        } catch { $checksumUnavailable = $true }
    }

    # 完整摘要默认直接判定内容；显式 HTTP 判据仍与声明摘要组合比较。
    # hashFile 默认复用匹配声明指纹的期望摘要，显式 checksum 才强制重新请求。
    $httpCriteria = @($criteria | Where-Object { $_ -ne 'checksum' })
    $evaluateHttp = -not $compareInfo.IsDefault -or -not ($header -or $hasDeclaredChecksum)
    if ($evaluateHttp -and $httpCriteria.Count -gt 0 -and $sameOrigin) {
        $validators = Get-WinstRemoteValidators -Context $Context -Uri $url
        if ($validators.Ok) {
            $localSize = $null
            try { $localSize = (Get-Item -LiteralPath $target -Force -ErrorAction Stop).Length } catch { }
            # 缺少旧实体标识不能证明远端变化；解析时只比较已有基线，下载层可选择重取建基线。
            $comparableCriteria = @($httpCriteria | Where-Object {
                $_ -eq 'size' -or ($_ -eq 'etag' -and $meta.ETag) -or ($_ -eq 'lastmodified' -and $meta.LastModified)
            })
            $comparison = Compare-WinstFileValidators -Criteria $comparableCriteria -Meta $meta -Validators $validators -LocalSize $localSize
            $compared += [int]$comparison.Compared
            if ($comparison.Changed) { $changed = $true }
        }
    }
    if ($changed) {
        $Plan['remoteFresh'] = 'changed'
    } elseif ($compared -gt 0 -and -not $checksumUnavailable) {
        if (-not $recordedHash) { $recordedHash = Get-WinstPackageFileHash -Path $target }
        if ($recordedHash) {
            $Plan['remoteFreshHash'] = $recordedHash
            $Plan['remoteFresh'] = 'unchanged'
        }
    }
}
