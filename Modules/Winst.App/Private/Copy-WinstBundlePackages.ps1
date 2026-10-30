#Requires -Version 5.1

function Copy-WinstBundlePackages {
    <#
    .SYNOPSIS
        ⑦ 复制安装包到 <目标>\apps\<id>\，并把摘要 / 文件元数据写进套件索引。
    .OUTPUTS
        @{ Copied; Skipped; KitIndex; Errors }
    #>
    param(
        $CopyItems,
        [string]$KitAppsDir,
        $SourceCacheIndex,
        # 越界护栏的根：必须在参数里显式传入。若从调用方局部变量隐式取值（PowerShell 动态作用域），
        # 换调用方 / 改名就会让 -AllowedRoot 变空，只剩受保护目录黑名单。
        [string]$TargetDir = '',
        [switch]$DryRun
    )
    if (-not $TargetDir) { $TargetDir = $KitAppsDir }

    $kitIndex = New-WinstOrdinalDictionary
    if (Test-Path -LiteralPath $KitAppsDir -PathType Container) {
        try { $kitIndex = (Read-WinstCacheIndex -PkgDir $KitAppsDir).Index } catch { $kitIndex = New-WinstOrdinalDictionary }
    }

    $errors = @()
    $copied = 0
    $skipped = 0
    foreach ($entry in @($CopyItems)) {
        $item = $entry['Item']
        $id = [string]$item['Id']
        $sourceDir = [string]$item['CacheDir']
        $sourceFiles = @($item['CacheFiles'])
        $sourceVersion = [string]$item['CacheVersion']

        # id 会拼成 U 盘上的目录名：拒绝 ../ 与非目录名，避免清单把内容写到套件目录之外
        if (-not (Test-WinstSafePathSegment -Name $id)) {
            $errors += ('{0}: id 不合法，无法作为目录名' -f $id)
            Write-Host ('  失败: {0}' -f $errors[-1]) -ForegroundColor Red
            continue
        }
        $targetIdDir = Join-WinstPath $KitAppsDir $id

        # 版本相同且文件齐全 → 跳过；U 盘里是别的版本 → 先清掉这个软件的旧目录再整份复制
        $existingVersion = ''
        if ($kitIndex.Contains($id)) { $existingVersion = Get-EntryString -Entry $kitIndex[$id] -Key 'version' }
        $sameVersion = [bool]($existingVersion -and $sourceVersion -and ($existingVersion -eq $sourceVersion))
        $allPresent = $true
        foreach ($fileName in $sourceFiles) {
            if (-not (Test-Path -LiteralPath (Join-WinstPath $targetIdDir $fileName) -PathType Leaf)) { $allPresent = $false; break }
        }

        if ($sameVersion -and $allPresent) {
            $skipped++
            Write-Host ('  跳过（目标已有相同版本）: {0} {1}' -f [string]$item['DisplayName'], $sourceVersion) -ForegroundColor DarkGray
            continue
        }

        $replacing = $false
        if (-not $sameVersion -and (Test-Path -LiteralPath $targetIdDir -PathType Container)) { $replacing = $true }
        $oldVersionText = $existingVersion
        if (-not $oldVersionText) { $oldVersionText = '未知版本' }

        if ($DryRun) {
            if ($replacing) {
                Write-Host ('  将覆盖旧版本: {0}（{1} -> {2}，{3} 个文件）' -f [string]$item['DisplayName'], $oldVersionText, $sourceVersion, $sourceFiles.Count) -ForegroundColor Gray
            } else {
                Write-Host ('  将复制: {0}（{1}，{2} 个文件）-> {3}' -f [string]$item['DisplayName'], $sourceVersion, $sourceFiles.Count, $targetIdDir) -ForegroundColor Gray
            }
            $copied++
            continue
        }

        try {
            Assert-WinstSafeWritePath -Path $targetIdDir -Directory
            Assert-WinstDistinctIds -Ids @(@($kitIndex.Keys) + @($id))
            # 版本不同：先删掉 U 盘上这个软件的旧目录，避免新旧文件混在一起
            if ($replacing) {
                Clear-WinstInstallDir -Dir $targetIdDir -AllowedRoot $TargetDir
                if (Test-Path -LiteralPath $targetIdDir) { throw ('无法安全清理目标旧目录：{0}' -f $targetIdDir) }
            }
            if (-not (Test-Path -LiteralPath $targetIdDir -PathType Container)) {
                $null = New-Item -ItemType Directory -Path $targetIdDir -Force -ErrorAction Stop
            }
            foreach ($fileName in $sourceFiles) {
                Copy-Item -LiteralPath (Join-WinstPath $sourceDir $fileName) -Destination (Join-WinstPath $targetIdDir $fileName) -Force -ErrorAction Stop
            }
            $copied++
            if ($replacing) {
                Write-Host ('  已覆盖旧版本: {0}（{1} -> {2}，{3} 个文件）' -f [string]$item['DisplayName'], $oldVersionText, $sourceVersion, $sourceFiles.Count) -ForegroundColor Green
            } else {
                Write-Host ('  已复制: {0}（{1}，{2} 个文件）' -f [string]$item['DisplayName'], $sourceVersion, $sourceFiles.Count) -ForegroundColor Green
            }
        } catch {
            $errors += ('{0}: {1}' -f $id, $_.Exception.Message)
            Write-Host ('  失败: {0}' -f $errors[-1]) -ForegroundColor Red
            continue
        }

        # 摘要 / 文件元数据：优先取「来源缓存索引」里那份（与刚复制的文件一一对应）；
        # 版本没变时才沿用目标索引里的旧记录（同版本才保证描述的是同一批文件）
        $hashes = New-WinstOrdinalDictionary
        $manifestHashes = New-WinstOrdinalDictionary
        $fileMeta = New-WinstOrdinalDictionary
        if ($SourceCacheIndex -and $SourceCacheIndex.Contains($id)) {
            $srcHashes = Get-EntryValue -Entry $SourceCacheIndex[$id] -Key 'hashes' -Default $null
            if ($srcHashes) { $hashes = $srcHashes }
            # 复制的文件与来源一致，按声明算法记录的摘要同样有效，一并带过去
            $srcManifestHashes = Get-EntryValue -Entry $SourceCacheIndex[$id] -Key 'manifestHashes' -Default $null
            if ($srcManifestHashes) { $manifestHashes = $srcManifestHashes }
            $fileMeta = Copy-WinstFileMeta -FileMeta (Get-EntryValue -Entry $SourceCacheIndex[$id] -Key 'fileMeta' -Default $null)
        } elseif ($sameVersion -and $kitIndex.Contains($id)) {
            $oldHashes = Get-EntryValue -Entry $kitIndex[$id] -Key 'hashes' -Default $null
            if ($oldHashes) { $hashes = $oldHashes }
            $oldManifestHashes = Get-EntryValue -Entry $kitIndex[$id] -Key 'manifestHashes' -Default $null
            if ($oldManifestHashes) { $manifestHashes = $oldManifestHashes }
        }
        Set-WinstCacheIndexEntry -Index $kitIndex -Id $id -Version $sourceVersion -Files @($sourceFiles) -Hashes $hashes -ManifestHashes $manifestHashes -FileMeta $fileMeta
    }

    return @{ Copied = $copied; Skipped = $skipped; KitIndex = $kitIndex; Errors = @($errors) }
}
