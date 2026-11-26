#Requires -Version 5.1

function Update-WinstPackageCacheIndex {
    <#
    .SYNOPSIS
        在索引锁内登记已完成的文件。全部完成后按清单裁剪旧记录。
    #>
    param([hashtable]$Context, [string]$Id, $FilePlan, [string[]]$PlanNames,
        [string]$Version, [switch]$Downloaded, [switch]$Complete)

    $name = [string]$FilePlan['Name']
    $hash = [string]$FilePlan['IndexHash']
    if (-not $hash) { $hash = Get-WinstPackageFileHash -Path $FilePlan['Target'] }
    if (-not $hash) { throw ('无法计算缓存文件摘要：{0}' -f $name) }
    $FilePlan['IndexHash'] = $hash
    $size = (Get-Item -LiteralPath $FilePlan['Target'] -Force -ErrorAction Stop).Length

    Save-WinstCacheIndex -PkgDir $Context.PkgDir -UpdateIds @($Id) -Update {
        param($index)
        $entry = $index[$Id]
        $names = $PlanNames
        if (-not $Complete) {
            $names = @(Get-EntryArray -Entry $entry -Key 'files')
            if ($name -ieq $PlanNames[0]) { $names = @($name) + @($names -ne $name) }
            elseif ($names -notcontains $name) { $names += $name }
        }
        $hashes = Get-EntryValue -Entry $entry -Key 'hashes'
        $manifestHashes = Get-EntryValue -Entry $entry -Key 'manifestHashes'
        $fileMeta = Get-EntryValue -Entry $entry -Key 'fileMeta'
        if ($null -eq $hashes) { $hashes = New-WinstOrdinalDictionary -IgnoreCase }
        if ($null -eq $manifestHashes) { $manifestHashes = New-WinstOrdinalDictionary -IgnoreCase }
        if ($null -eq $fileMeta) { $fileMeta = New-WinstOrdinalDictionary -IgnoreCase }

        if ($Downloaded) {
            $null = $manifestHashes.Remove($name)
            $null = $fileMeta.Remove($name)
        }
        $hashes[$name] = $hash.ToLowerInvariant()
        $algorithm = [string]$FilePlan['ExpectedAlgorithm']
        if ($algorithm -and $algorithm -ne 'SHA256' -and $FilePlan['ManifestHash']) {
            Set-WinstManifestHash -Container $manifestHashes -FileName $name -Algorithm $algorithm -Hash $FilePlan['ManifestHash']
        }
        $fields = @{ Size = $size }
        $origin = [string]$FilePlan['ManifestOrigin']
        if ($Downloaded) {
            $fields['DownloadedAt'] = (Get-Date).ToString('s')
            $fields['LastCheckedAt'] = $fields['DownloadedAt']
            $fields['SourceVersion'] = [string]$FilePlan['FileVersion']
            $fields['Url'] = [string]$FilePlan['Url']
            $fields['ManifestOrigin'] = $origin
        } elseif ($FilePlan['ExpectedHash'] -and $origin -and
                (-not $fileMeta.Contains($name) -or $fileMeta[$name]['manifestOrigin'] -cne $origin)) {
            $fields['ManifestOrigin'] = $origin
            $fields['Url'] = [string]$FilePlan['Url']
            $fields['SourceVersion'] = [string]$FilePlan['FileVersion']
            $fields['ETag'] = ''
            $fields['LastModified'] = ''
        }
        if ($FilePlan['CheckedAt']) {
            $fields['ETag'] = [string]$FilePlan['ValidatorETag']
            $fields['LastModified'] = [string]$FilePlan['ValidatorLastModified']
            $fields['LastCheckedAt'] = [string]$FilePlan['CheckedAt']
        }
        if ([string]$FilePlan['ChecksumMetadataAction'] -eq 'replace') {
            $fields['ExpectedHash'] = [string]$FilePlan['ExpectedHash']
            $fields['ExpectedAlgorithm'] = $algorithm
            $fields['ChecksumHashFile'] = [string]$FilePlan['ChecksumHashFile']
            $fields['ChecksumHashFrom'] = [string]$FilePlan['ChecksumHashFrom']
            $fields['ChecksumFingerprint'] = ''
            if ($fields['ChecksumHashFile']) {
                $fields['ChecksumFingerprint'] = Get-WinstChecksumDeclarationFingerprint -FileName $name `
                    -HashFile $fields['ChecksumHashFile'] -HashFrom $fields['ChecksumHashFrom'] `
                    -FileUrl ([string]$FilePlan['Url']) -FileVersion ([string]$FilePlan['FileVersion'])
            }
        }
        Set-WinstFileMetaValue -Container $fileMeta -FileName $name @fields

        if ($Complete) {
            foreach ($map in @($hashes, $manifestHashes, $fileMeta)) {
                foreach ($key in @($map.Keys)) {
                    if ($names -notcontains $key) { $map.Remove($key) }
                }
            }
        }
        $bundleSource = Get-EntryString -Entry $entry -Key 'bundleSource'
        $mainOrigin = Get-EntryString -Entry $fileMeta[$names[0]] -Key 'manifestOrigin'
        if ($bundleSource -and $mainOrigin) { $bundleSource = $mainOrigin }
        Set-WinstCacheIndexEntry -Index $index -Id $Id -Version $Version -BundleSource $bundleSource `
            -Files $names -Hashes $hashes -ManifestHashes $manifestHashes -FileMeta $fileMeta
    }
}
