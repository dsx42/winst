#Requires -Version 5.1

function Copy-WinstBundlePackages {
    <#
    .SYNOPSIS
        复制安装包到 <目标>\apps\<id>\，并登记与副本对应的摘要和来源。
    .OUTPUTS
        @{ Copied; Skipped; Errors }
    #>
    param(
        [hashtable]$Context,
        $CopyItems,
        [string]$KitAppsDir,
        $SourceCacheIndex,
        [Parameter(Mandatory = $true)][string]$TargetDir,
        [switch]$DryRun
    )

    $sourceRoot = [string]$Context.PkgDir
    if ((Test-WinstPathUnderRoot -Path $KitAppsDir -Root $sourceRoot -AllowEqual) -or
        (Test-WinstPathUnderRoot -Path $sourceRoot -Root $KitAppsDir -AllowEqual)) {
        return @{ Copied = 0; Skipped = 0; Errors = @('套件包目录不能与来源目录重叠。') }
    }
    $lockRoots = @($sourceRoot, $KitAppsDir)
    [array]::Sort($lockRoots, [StringComparer]::OrdinalIgnoreCase)

    $errors = @()
    $copied = 0
    $skipped = 0
    foreach ($item in @($CopyItems)) {
        $id = [string]$item['Id']
        $locks = @()
        try {
            if (-not (Test-WinstSafePathSegment -Name $id) -or (Test-WinstReservedPackageId -Id $id)) {
                throw 'id 不合法，无法作为目录名'
            }
            $sourceDir = Join-WinstPath $sourceRoot $id
            $targetIdDir = Join-WinstPath $KitAppsDir $id
            Assert-WinstSafeWritePath -Path $sourceDir
            Assert-WinstSafeWritePath -Path $targetIdDir -Directory
            if (-not $DryRun) {
                foreach ($root in $lockRoots) {
                    $locks += Enter-WinstPackageLock -PkgDir $root -Id $id
                }
            }

            $sourceEntry = $SourceCacheIndex[$id]
            if (-not $DryRun) {
                $sourceRead = Read-WinstCacheIndex -PkgDir $sourceRoot -Ids @($id)
                if (-not (Test-WinstJsonValueEqual -Left $sourceEntry -Right $sourceRead.Index[$id])) {
                    throw '来源包在核对后已变更，请重新制作套件。'
                }
            }
            $source = Get-Item -LiteralPath $sourceDir -Force -ErrorAction Stop
            Assert-WinstDistinctIds -Ids @($source.Name, $id)
            $sourceFiles = @($item['CacheFiles'])
            $sourceVersion = [string]$item['CacheVersion']
            $plan = $item['PlanEntry']['Plan']
            if (-not $DryRun -and -not $sourceVersion -and (Get-EntryBool -Entry $plan -Key 'versionFromPackage')) {
                $versionInput = Get-WinstPackageVersionInput -Plan $plan
                $sourceVersion = Read-WinstPackageVersion -Context $Context -Plan $plan -PkgDir $sourceDir -InputName $versionInput.Name
                Save-WinstCacheIndex -PkgDir $sourceRoot -UpdateIds @($id) -Update {
                    param($index)
                    if ($index.Contains($id)) { $index[$id]['version'] = $sourceVersion }
                    else { Set-WinstCacheIndexEntry -Index $index -Id $id -Version $sourceVersion -Files $sourceFiles }
                }
            }
            $target = Get-Item -LiteralPath $targetIdDir -Force -ErrorAction SilentlyContinue
            if ($target -and $target.Name -cne $id) {
                Assert-WinstDistinctIds -Ids @($target.Name, $id)
            }
            $targetEntry = $null
            if ($target) {
                $targetRead = Read-WinstCacheIndex -PkgDir $KitAppsDir -Ids @($id)
                $targetEntry = $targetRead.Index[$id]
            }
            $oldVersion = Get-EntryString -Entry $targetEntry -Key 'version'
            $sameVersion = $oldVersion -and $sourceVersion -and $oldVersion -ceq $sourceVersion
            $obsolete = @(Get-EntryArray -Entry $targetEntry -Key 'files' | Where-Object { $sourceFiles -notcontains $_ })
            $replacing = [bool]($target -and (-not $sameVersion -or $obsolete.Count))

            $hashes = New-WinstOrdinalDictionary -IgnoreCase
            $manifestHashes = New-WinstOrdinalDictionary -IgnoreCase
            $fileMeta = New-WinstOrdinalDictionary -IgnoreCase
            $sourceManifestHashes = Get-EntryValue -Entry $sourceEntry -Key 'manifestHashes'
            $sourceFileMeta = Get-EntryValue -Entry $sourceEntry -Key 'fileMeta'
            $changed = @()
            foreach ($fileName in $sourceFiles) {
                if (-not (Test-WinstSafePathSegment -Name $fileName)) { throw ('缓存文件名不合法：{0}' -f $fileName) }
                $sourcePath = Join-WinstPath $sourceDir $fileName
                $targetPath = Join-WinstPath $targetIdDir $fileName
                Assert-WinstSafeWritePath -Path $sourcePath
                $sourceFile = Get-Item -LiteralPath $sourcePath -Force -ErrorAction Stop
                if ($sourceFile.PSIsContainer) { throw ('缓存成员不是文件：{0}' -f $fileName) }
                Assert-WinstSafeWritePath -Path $targetPath

                $sourceHash = Get-WinstRecordedHash -Entry $sourceEntry -FileName $fileName
                $identical = $false
                if ($sameVersion -and -not $replacing -and (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
                    $targetHash = Get-WinstRecordedHash -Entry $targetEntry -FileName $fileName
                    if (-not $sourceHash -or -not $targetHash) {
                        if (-not $sourceHash) { $sourceHash = Get-WinstFileHash -Path $sourcePath }
                        if (-not $targetHash) { $targetHash = Get-WinstFileHash -Path $targetPath }
                        if (-not $sourceHash -or -not $targetHash) { throw ('无法比较套件文件：{0}' -f $fileName) }
                    }
                    $identical = $sourceHash -ieq $targetHash
                }
                if (-not $identical) { $changed += $fileName }
                if ($sourceHash) { $hashes[$fileName] = $sourceHash }
                if ($sourceManifestHashes -and $sourceManifestHashes.Contains($fileName)) {
                    $manifestHashes[$fileName] = $sourceManifestHashes[$fileName]
                }
                if ($sourceFileMeta -and $sourceFileMeta.Contains($fileName)) {
                    $fileMeta[$fileName] = $sourceFileMeta[$fileName]
                }
            }

            if (-not $DryRun) {
                if ($changed.Count) {
                    if ($targetEntry) {
                        # 文件替换到一半时，索引不能继续证明旧内容。
                        Save-WinstCacheIndex -PkgDir $KitAppsDir -UpdateIds @($id) -Update {
                            param($index)
                            $index.Remove($id)
                        }
                    }
                    if ($replacing) {
                        Clear-WinstInstallDir -Dir $targetIdDir -AllowedRoot $TargetDir
                        if (Test-Path -LiteralPath $targetIdDir) { throw ('无法安全清理目标旧目录：{0}' -f $targetIdDir) }
                    }
                    if (-not (Test-Path -LiteralPath $targetIdDir -PathType Container)) {
                        $null = New-Item -ItemType Directory -Path $targetIdDir -Force -ErrorAction Stop
                    }
                    foreach ($fileName in $changed) {
                        Copy-WinstBundleItem -Source (Join-WinstPath $sourceDir $fileName) -Destination (Join-WinstPath $targetIdDir $fileName)
                    }
                }
                Save-WinstCacheIndex -PkgDir $KitAppsDir -UpdateIds @($id) -Update {
                    param($index)
                    Set-WinstCacheIndexEntry -Index $index -Id $id -Version $sourceVersion -Files $sourceFiles `
                        -Hashes $hashes -ManifestHashes $manifestHashes -FileMeta $fileMeta `
                        -DownloadedAt (Get-EntryString -Entry $sourceEntry -Key 'downloadedAt') `
                        -BundleSource ([string]$item['PlanEntry']['Source'])
                }
            }

            $name = [string]$item['DisplayName']
            $versionText = $sourceVersion
            if (-not $versionText) { $versionText = '缓存版本未知' }
            if ($changed.Count) {
                $copied++
                if ($replacing) {
                    if (-not $oldVersion) { $oldVersion = '未知版本' }
                    $action = '已替换旧目录'
                    if ($DryRun) { $action = '将替换旧目录' }
                    Write-Host ('  {0}: {1}（{2} -> {3}，{4} 个文件）' -f $action, $name, $oldVersion, $versionText, $changed.Count) -ForegroundColor Gray
                } else {
                    $action = '已复制'
                    if ($DryRun) { $action = '将复制' }
                    Write-Host ('  {0}: {1}（{2}，{3} 个文件）-> {4}' -f $action, $name, $versionText, $changed.Count, $targetIdDir) -ForegroundColor Gray
                }
            } else {
                $skipped++
                Write-Host ('  跳过（目标文件内容相同）: {0} {1}' -f $name, $versionText) -ForegroundColor DarkGray
            }
        } catch {
            $errors += ('{0}: {1}' -f $id, $_.Exception.Message)
            Write-Host ('  失败: {0}' -f $errors[-1]) -ForegroundColor Red
        } finally {
            foreach ($lock in $locks) { $lock.Dispose() }
        }
    }

    return @{ Copied = $copied; Skipped = $skipped; Errors = @($errors) }
}
