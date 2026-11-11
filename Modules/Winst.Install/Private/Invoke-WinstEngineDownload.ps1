#Requires -Version 5.1

function Invoke-WinstEngineDownload {
    <#
    .SYNOPSIS
        ① 引擎自动引导下载（直接 HTTP）：逐文件下载 + 校验 + 写缓存索引 + 清理旧包。
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
    $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    $index = $indexRead.Index
    $previousEntry = $null
    if ($index.Contains($PlanId)) { $previousEntry = $index[$PlanId] }

    # 缓存里已有需要的包（且校验码一致 / 新鲜度判定命中）就跳过下载，不重复下载
    $plans = @(Get-WinstPackageFilePlans -Context $Context -Index $index -Id $PlanId -Files $files -CheckValidators)
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

        Confirm-WinstCachedFilePlan -Context $Context -FilePlan $filePlan
        if ($filePlan['ValidationError']) {
            return @{ Ok = $false; Error = ('{0} 无法验证缓存：{1}' -f $name, $filePlan['ValidationError']); PrimaryPath = $primaryPath; Files = $indexNames }
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
                -FileUrl $url -FileVersion ([string]$filePlan['FileVersion'])
            if (-not $check.Ok) {
                Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
                return @{ Ok = $false; Error = ('{0} 校验失败：{1}' -f $name, $check.Error); PrimaryPath = $primaryPath; Files = $indexNames }
            }
            Set-WinstFilePlanIntegrityFromCheck -FilePlan $filePlan -Check $check
            $downloadedNames += $name
        }

        $indexNames += $name
        if (-not $primaryPath) { $primaryPath = $target }
    }

    Update-WinstPackageCacheIndex -Context $Context -Id $PlanId -Plans $plans -PrevEntry $previousEntry `
        -Version (Get-EntryString -Entry $Plan -Key 'version') -DownloadedNames $downloadedNames
    Remove-WinstObsoletePackages -Context $Context -Id $PlanId -Plans $plans -DownloadedAny ($downloadedNames.Count -gt 0)

    return @{ Ok = $true; Error = ''; PrimaryPath = $primaryPath; Files = $indexNames }
}
