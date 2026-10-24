#Requires -Version 5.1

function Invoke-WinstEngineDownload {
    <#
    .SYNOPSIS
        ① 引擎引导下载（唯一允许 IWR 的路径）：逐文件下载 + 校验 + 写缓存索引 + 清理旧包。
    .OUTPUTS
        @{ Ok; Error; PrimaryPath; Files }
    #>
    param([hashtable]$Context, [string]$Id, $Plan, [string]$PlanId, [switch]$Quiet)

    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) {
        return @{ Ok = $false; Error = ('{0} 的软件定义里没有可下载的文件' -f $Id); PrimaryPath = ''; Files = @() }
    }

    $primaryPath = ''
    $indexNames = @()
    $indexHashes = New-WinstOrdinalDictionary
    $indexManifestHashes = New-WinstOrdinalDictionary
    $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    $index = $indexRead.Index
    # fileMeta：先继承索引里已有的记账
    $indexFileMeta = Copy-WinstFileMeta -FileMeta (Get-EntryValue -Entry $(if ($index.Contains($PlanId)) { $index[$PlanId] } else { $null }) -Key 'fileMeta' -Default $null)

    # 缓存里已有需要的包（且校验码一致 / 新鲜度判定命中）就跳过下载，不重复下载
    $plans = @(Get-WinstPackageFilePlans -Context $Context -Index $index -Id $PlanId -Files $files -CheckValidators `
        -SourceVersion (Get-EntryString -Entry $Plan -Key 'version'))
    $downloadedNames = @()
    foreach ($filePlan in $plans) {
        $url = [string]$filePlan['Url']
        $name = [string]$filePlan['Name']
        $target = [string]$filePlan['Target']
        if (-not $name -or -not $target) {
            return @{ Ok = $false; Error = ('{0} 的下载地址里无法确定文件名：{1}' -f $Id, $url); PrimaryPath = $primaryPath; Files = $indexNames }
        }
        if ($filePlan['Notice'] -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            Write-Host ('  [verbose] {0}' -f [string]$filePlan['Notice']) -ForegroundColor DarkGray
        }
        if ($filePlan['Hint'] -and -not $Quiet) {
            Write-Host ('    提示: {0}' -f [string]$filePlan['Hint']) -ForegroundColor DarkYellow
        }

        if ($filePlan['NeedDownload']) {
            if ($filePlan['Reason'] -and -not $Quiet) {
                Write-Host ('    {0}: {1}' -f $name, $filePlan['Reason']) -ForegroundColor DarkYellow
            }
            if (-not $Quiet) { Write-Host ('    下载 {0} …' -f $name) -ForegroundColor Gray }
            $dl = Save-WinstFileWithHttp -Context $Context -Uri $url -OutFile $target
            if (-not $dl.Ok) {
                return @{ Ok = $false; Error = ('下载 {0} 失败：{1}' -f $name, $dl.Error); PrimaryPath = $primaryPath; Files = $indexNames }
            }
            $check = Test-WinstFileIntegrity -Context $Context -FilePath $target -FileDecl $filePlan['Decl'] `
                -FileUrl $url -SourceVersion (Get-EntryString -Entry $Plan -Key 'version')
            if (-not $check.Ok) {
                Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
                return @{ Ok = $false; Error = ('{0} 校验失败：{1}' -f $name, $check.Error); PrimaryPath = $primaryPath; Files = $indexNames }
            }
            Set-WinstFilePlanIntegrityFromCheck -FilePlan $filePlan -Check $check
            $downloadedNames += $name
        }

        $indexNames += $name
        # hashes 统一存 sha256（软件源声明的摘要算法不同、如 Maven 的 .sha512 时这里现算一次）；
        # manifestHashes 存按声明算法的摘要，两者写回后下次命中判定都不用再算
        $indexHash = Get-WinstIndexHashForPlan -FilePath $target -Plan $filePlan
        if ($indexHash) { $indexHashes[$name] = $indexHash }
        $manifestHash = Get-WinstManifestHashFromPlan -Plan $filePlan
        if ($manifestHash.Hash) {
            $null = Set-WinstManifestHash -Container $indexManifestHashes -FileName $name -Algorithm $manifestHash.Algorithm -Hash $manifestHash.Hash
        }

        # fileMeta：引擎包同样按文件记账
        $size = $null
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            try { $size = (Get-Item -LiteralPath $target -Force).Length } catch { $size = $null }
        }
        $downloadedAt = ''
        if ($downloadedNames -contains $name) { $downloadedAt = (Get-Date).ToString('s') }
        $checkedAt = [string]$filePlan['CheckedAt']
        if (-not $checkedAt -and $downloadedAt) { $checkedAt = $downloadedAt }
        $null = Set-WinstFileMetaValue -Container $indexFileMeta -FileName $name `
            -Url $url -SourceVersion ([string]$filePlan['FileVersion']) -Size $size `
            -DownloadedAt $downloadedAt -LastCheckedAt $checkedAt `
            -ETag ([string]$filePlan['ValidatorETag']) -LastModified ([string]$filePlan['ValidatorLastModified'])
        if ([string]$filePlan['ChecksumMetadataAction'] -eq 'replace') {
            $null = Set-WinstFileMetaValue -Container $indexFileMeta -FileName $name `
                -ExpectedHash ([string]$filePlan['ExpectedHash']) -ExpectedAlgorithm ([string]$filePlan['ExpectedAlgorithm']) `
                -ChecksumHashFile ([string]$filePlan['ChecksumHashFile']) -ChecksumHashFrom ([string]$filePlan['ChecksumHashFrom']) `
                -ChecksumFingerprint ([string]$filePlan['ChecksumFingerprint'])
        }
        if (-not $primaryPath) { $primaryPath = $target }
    }

    # 本次不需要的文件连记账一起清掉
    foreach ($metaKey in @($indexFileMeta.Keys)) {
        if ($indexNames -notcontains [string]$metaKey) { $indexFileMeta.Remove($metaKey) }
    }
    Set-WinstCacheIndexEntry -Index $index -Id $PlanId -Version (Get-EntryString -Entry $Plan -Key 'version') -Files $indexNames -Hashes $indexHashes -ManifestHashes $indexManifestHashes -FileMeta $indexFileMeta
    Save-WinstCacheIndex -PkgDir $Context.PkgDir -Index $index

    # 自动清理旧版本的引擎包文件（与其他软件同一套 8.4 清理口径，pruneOldPackages 开关）：
    # 引擎包文件名带版本，只清记账不清文件的话旧版本 zip 会在安装包位置越积越多
    $prune = $true
    try { $prune = [bool](Get-ConfigValue -Config $Context.Config -Key 'pruneOldPackages') } catch { $prune = $true }
    if ($prune) {
        $removedOld = @(Remove-WinstOldPackages -Context $Context -Id $PlanId -KeepFiles $indexNames)
        if ($removedOld.Count -gt 0) {
            if (-not $Quiet) {
                Write-Host ('    已清理旧版本的引擎包: {0}' -f ($removedOld -join '、')) -ForegroundColor DarkYellow
            } elseif ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                Write-Host ('  [verbose] 已清理旧版本的引擎包: {0}' -f ($removedOld -join '、')) -ForegroundColor DarkGray
            }
        }
    }

    return @{ Ok = $true; Error = ''; PrimaryPath = $primaryPath; Files = $indexNames }
}
