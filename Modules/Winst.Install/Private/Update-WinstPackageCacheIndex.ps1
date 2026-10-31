#Requires -Version 5.1

function Update-WinstPackageCacheIndex {
    <#
    .SYNOPSIS
        写回缓存索引：版本 + 文件名 + 每个包文件的校验码与 fileMeta（写回前重读，避免抹掉引擎中途更新）。
    #>
    param([hashtable]$Context, [string]$Id, $Plans, $PrevEntry, [string]$Version, $DownloadedNames)

    $indexNames = @()
    $indexHashes = New-WinstOrdinalDictionary
    $indexManifestHashes = New-WinstOrdinalDictionary
    # fileMeta：每个文件的实际地址 / 本次版本 / 校验器基线 / 大小与时间——
    # 先继承索引里已有的记账（本次没重新确认的文件保留原值），再按本次解析与确认结果更新
    $indexFileMeta = Copy-WinstFileMeta -FileMeta (Get-EntryValue -Entry $PrevEntry -Key 'fileMeta' -Default $null)
    $stampNow = (Get-Date).ToString('s')
    foreach ($filePlan in @($Plans)) {
        $name = [string]$filePlan['Name']
        if (-not $name) { continue }
        $wasDownloaded = @($DownloadedNames) -contains $name
        if ($indexNames -notcontains $name) { $indexNames += $name }
        $hash = Get-WinstIndexHashForPlan -FilePath ([string]$filePlan['Target']) -Plan $filePlan
        if (-not $hash -and -not $wasDownloaded) { $hash = Get-WinstRecordedHash -Entry $PrevEntry -FileName $name }
        if ($hash) { $indexHashes[$name] = $hash }
        $manifestHash = Get-WinstManifestHashFromPlan -Plan $filePlan
        if (-not $manifestHash.Hash -and -not $wasDownloaded) {
            $manifestHash.Hash = Get-WinstManifestHash -Entry $PrevEntry -FileName $name -Algorithm $manifestHash.Algorithm
        }
        if ($manifestHash.Hash) {
            $null = Set-WinstManifestHash -Container $indexManifestHashes -FileName $name -Algorithm $manifestHash.Algorithm -Hash $manifestHash.Hash
        }

        $size = $null
        $path = [string]$filePlan['Target']
        if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
            try { $size = (Get-Item -LiteralPath $path -Force).Length } catch { $size = $null }
        }
        $downloadedAt = ''
        if ($wasDownloaded) { $downloadedAt = $stampNow }
        $checkedAt = [string]$filePlan['CheckedAt']
        if (-not $checkedAt -and $downloadedAt) { $checkedAt = $downloadedAt }
        $null = Set-WinstFileMetaValue -Container $indexFileMeta -FileName $name `
            -Url ([string]$filePlan['Url']) -SourceVersion ([string]$filePlan['FileVersion']) -Size $size `
            -DownloadedAt $downloadedAt -LastCheckedAt $checkedAt `
            -ETag ([string]$filePlan['ValidatorETag']) -LastModified ([string]$filePlan['ValidatorLastModified'])
        if ([string]$filePlan['ChecksumMetadataAction'] -eq 'replace') {
            # 包内派生版本可能在下载校验后才确定，来源指纹必须绑定最终写入解析锁的版本。
            if ($filePlan['ChecksumHashFile']) {
                $filePlan['ChecksumFingerprint'] = Get-WinstChecksumDeclarationFingerprint -FileName $name `
                    -FileDecl $filePlan['Decl'] -FileUrl ([string]$filePlan['Url']) -SourceVersion $Version
            }
            $null = Set-WinstFileMetaValue -Container $indexFileMeta -FileName $name `
                -ExpectedHash ([string]$filePlan['ExpectedHash']) -ExpectedAlgorithm ([string]$filePlan['ExpectedAlgorithm']) `
                -ChecksumHashFile ([string]$filePlan['ChecksumHashFile']) -ChecksumHashFrom ([string]$filePlan['ChecksumHashFrom']) `
                -ChecksumFingerprint ([string]$filePlan['ChecksumFingerprint'])
        }
    }
    # 本次不需要的文件连记账一起清掉
    foreach ($metaKey in @($indexFileMeta.Keys)) {
        if ($indexNames -notcontains [string]$metaKey) { $indexFileMeta.Remove($metaKey) }
    }
    # 写回前重读最新索引：引擎引导（Confirm-* → Update-WinstEngineIfOutdated → Install-WinstEngine）
    # 引擎自动更新可能在流程中途写过索引，而 $index 还是流程开始时的快照：
    # 直接整表写回会抹掉中途新增 / 更新的条目。重读后只合并本条目的记账，其它条目以最新为准
    $freshIndexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    $freshIndex = $freshIndexRead.Index
    Set-WinstCacheIndexEntry -Index $freshIndex -Id $Id -Version $Version -Files $indexNames -Hashes $indexHashes -ManifestHashes $indexManifestHashes -FileMeta $indexFileMeta
    Save-WinstCacheIndex -PkgDir $Context.PkgDir -Index $freshIndex
}
