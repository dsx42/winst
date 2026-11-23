#Requires -Version 5.1

function Update-WinstPackageCacheIndex {
    <#
    .SYNOPSIS
        写回缓存索引：版本 + 文件名 + 每个包文件的校验码与 fileMeta（写回前重读，避免抹掉引擎中途更新）。
    #>
    param([hashtable]$Context, [string]$Id, $Plans, $PrevEntry, [string]$Version, [string]$VersionFile, $VersionRule, $DownloadedNames)

    $indexNames = @()
    $indexHashes = New-WinstOrdinalDictionary -IgnoreCase
    $indexManifestHashes = New-WinstOrdinalDictionary -IgnoreCase
    # fileMeta：每个文件的实际地址 / 本次版本 / 校验器基线 / 大小与时间——
    # 先继承索引里已有的记账（本次没重新确认的文件保留原值），再按本次解析与确认结果更新
    $indexFileMeta = Copy-WinstFileMeta -FileMeta (Get-EntryValue -Entry $PrevEntry -Key 'fileMeta' -Default $null)
    $stampNow = (Get-Date).ToString('s')
    foreach ($filePlan in @($Plans)) {
        $name = [string]$filePlan['Name']
        if (-not $name) { continue }
        $wasDownloaded = @($DownloadedNames) -contains $name
        if ($indexNames -notcontains $name) { $indexNames += $name }
        $hash = $filePlan['IndexHash']
        if (-not $hash) { $hash = Get-WinstPackageFileHash -Path $filePlan['Target'] }
        if ($hash) { $indexHashes[$name] = $hash.ToLowerInvariant() }
        $filePlan['IndexHash'] = $hash
        $algorithm = [string]$filePlan['ExpectedAlgorithm']
        if ($algorithm -and $algorithm -ne 'SHA256') {
            $manifestHash = [string]$filePlan['ManifestHash']
            if ($manifestHash) {
                $null = Set-WinstManifestHash -Container $indexManifestHashes -FileName $name -Algorithm $algorithm -Hash $manifestHash
            }
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
        $validatorArgs = @{}
        $origin = [string]$filePlan['ManifestOrigin']
        if ($origin -and ($wasDownloaded -or $filePlan['ExpectedHash'])) {
            # 切换来源时重建这条记账，避免将旧来源的 HTTP 基线写到当前来源名下。
            if ($indexFileMeta.Contains($name) -and $indexFileMeta[$name]['manifestOrigin'] -cne $origin) {
                $indexFileMeta.Remove($name)
            }
            $validatorArgs['ManifestOrigin'] = $origin
        }
        if ($filePlan['CheckedAt']) {
            $validatorArgs['ETag'] = [string]$filePlan['ValidatorETag']
            $validatorArgs['LastModified'] = [string]$filePlan['ValidatorLastModified']
        }
        $null = Set-WinstFileMetaValue -Container $indexFileMeta -FileName $name @validatorArgs `
            -Url ([string]$filePlan['Url']) -SourceVersion ([string]$filePlan['FileVersion']) -Size $size `
            -DownloadedAt $downloadedAt -LastCheckedAt $checkedAt
        if ([string]$filePlan['ChecksumMetadataAction'] -eq 'replace') {
            # 指纹只绑定这一文件在下载声明中的版本。
            $checksumFingerprint = ''
            if ($filePlan['ChecksumHashFile']) {
                $checksumFingerprint = Get-WinstChecksumDeclarationFingerprint -FileName $name `
                    -HashFile ([string]$filePlan['ChecksumHashFile']) -HashFrom ([string]$filePlan['ChecksumHashFrom']) `
                    -FileUrl ([string]$filePlan['Url']) -FileVersion ([string]$filePlan['FileVersion'])
            }
            $null = Set-WinstFileMetaValue -Container $indexFileMeta -FileName $name `
                -ExpectedHash ([string]$filePlan['ExpectedHash']) -ExpectedAlgorithm ([string]$filePlan['ExpectedAlgorithm']) `
                -ChecksumHashFile ([string]$filePlan['ChecksumHashFile']) -ChecksumHashFrom ([string]$filePlan['ChecksumHashFrom']) `
                -ChecksumFingerprint $checksumFingerprint
        }
    }
    # 本次不需要的文件连记账一起清掉
    foreach ($metaKey in @($indexFileMeta.Keys)) {
        if ($indexNames -notcontains [string]$metaKey) { $indexFileMeta.Remove($metaKey) }
    }
    Save-WinstCacheIndex -PkgDir $Context.PkgDir -UpdateIds @($Id) -Update {
        param($index)
        $bundleSource = Get-EntryString -Entry $index[$Id] -Key 'bundleSource'
        $mainOrigin = Get-EntryString -Entry $indexFileMeta[$indexNames[0]] -Key 'manifestOrigin'
        if ($bundleSource -and $mainOrigin) { $bundleSource = $mainOrigin }
        Set-WinstCacheIndexEntry -Index $index -Id $Id -BundleSource $bundleSource -Version $Version -VersionFile $VersionFile -VersionRule $VersionRule -Files $indexNames -Hashes $indexHashes -ManifestHashes $indexManifestHashes -FileMeta $indexFileMeta
    }
}
