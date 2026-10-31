#Requires -Version 5.1
<#
    Get-WinstSelfPackageSource.ps1  (Winst.Install / Private)

    取得用于安装或更新 winst 自身的安装包。

    支持两种包形态
    --------------
    1. release 压缩包（常规路径）
           清单里 id "winst" 条目的 files[0]：GitHub release 资产，固定名 winst.zip、不带版本号
           （releases/latest/download/winst.zip 永远指向最新版）
       用 Invoke-WebRequest（Save-WinstFileWithHttp）下载，
       并按 files[0].hashFile 声明的 .zip.sha512 校验。

    2. 当前运行树（脚本 + Modules + 启动器 + LICENSE；仅用于引导首次安装）
           $script:WinstScriptPath
       取不到压缩包时使用：离线，或仓库还没有发布任何版本。
       更新不得回退到它，否则「更新」会静默重装同一版本。

    为什么 winst 自己用 Invoke-WebRequest
    --------------------------------------
    这段运行的时候下载引擎还不一定存在——安装 winst 的过程正是安装引擎的过程。
    引擎自身的引导出于同样原因有相同的豁免。

    .OUTPUTS
        @{ Ok; Error; ArchivePath; FallbackSourcePath; Downloaded; Resolved;
           Plan; SourceVersion; SourceName }
#>
function Get-WinstSelfPackageSource {
    <#
    .SYNOPSIS
        定位并下载 winst 的 release 压缩包，取不到时回退到
        当前运行的完整运行树。

    .PARAMETER RequireDownload
        指定后不允许用当前运行的脚本顶替。更新流程会用它，
        以保证更新要么真的升级、要么明确失败。

    .OUTPUTS
        @{ Ok; Error; ArchivePath; FallbackSourcePath; Downloaded; Resolved;
           Plan; SourceVersion; SourceName }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet,
        [switch]$RequireDownload
    )

    $selfId = 'winst'
    $archiveFileName = ('winst-{0}.zip' -f (Get-WinstProductVersion))

    $result = @{
        Ok                 = $false
        Error              = ''
        ArchivePath        = ''
        FallbackSourcePath = ''
        Downloaded         = $false
        Resolved           = $false
        Plan               = $null
        SourceVersion      = ''
        SourceName         = ''
    }

    # ---------------------------------------------------------- ① 软件定义
    $resolved = Get-WinstManifestAppPlan -Context $Context -Id $selfId -PreferSource (Get-WinstOfficialManifestName)

    $plan = $null
    $sourceVersion = ''
    $sourceName = ''

    if ($resolved.Ok) {
        $plan = $resolved.Plan
        $sourceVersion = Get-EntryString -Entry $plan -Key 'version'
        $sourceName = [string]$resolved.Source
    }

    $result.Plan = $plan
    $result.SourceVersion = $sourceVersion
    $result.SourceName = $sourceName

    # ------------------------------------------------------------ ② 取包
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)
    $errorText = ''

    if ($plan -and -not $offline) {
        $download = Get-EntryValue -Entry $plan -Key 'download' -Default $null
        $files = @(Get-EntryArray -Entry $download -Key 'files')
        $url = ''
        if ($files.Count -gt 0) { $url = Get-EntryString -Entry $files[0] -Key 'url' }

        if ($url) {
            $pkgDir = Join-WinstPath $Context.PkgDir $selfId
            if (-not (Test-Path -LiteralPath $pkgDir -PathType Container)) {
                $null = New-Item -ItemType Directory -Path $pkgDir -Force -ErrorAction SilentlyContinue
            }

            # 文件名与普通安装包使用相同规则，优先使用清单明确声明的名称。
            $archiveName = Get-EntryString -Entry $files[0] -Key 'name'
            if (-not $archiveName) { $archiveName = Get-FileNameFromUrl -Url $url }
            if (-not $archiveName) { $archiveName = $archiveFileName }

            if (-not (Test-WinstSafePathSegment -Name $archiveName)) {
                $errorText = ('winst 安装包的文件名不合法：{0}' -f $archiveName)
            } else {
                $archivePath = Join-WinstPath $pkgDir $archiveName

                # 自身包也使用统一索引，复用已记录的远端期望值和本地实测值。
                $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
                $prevEntry = $null
                if ($cacheRead.Index.Contains($selfId)) { $prevEntry = $cacheRead.Index[$selfId] }
                $packagePlans = @(Get-WinstPackageFilePlans -Context $Context -Index $cacheRead.Index -Id $selfId `
                    -Files @($files[0]) -CheckValidators -SourceVersion $sourceVersion)
                $filePlan = $packagePlans[0]
                if ($filePlan['ValidationError']) {
                    $result.Error = [string]$filePlan['ValidationError']
                    return $result
                }

                if (-not $filePlan['NeedDownload']) {
                    Update-WinstPackageCacheIndex -Context $Context -Id $selfId -Plans $packagePlans `
                        -PrevEntry $prevEntry -Version $sourceVersion -DownloadedNames @()
                    $result.ArchivePath = $archivePath
                    $result.Resolved = $true
                    $result.Ok = $true
                    return $result
                }

                if (-not $Quiet) { Write-Host ('    正在下载 {0} …' -f $archiveName) -ForegroundColor Gray }

                $dl = Save-WinstFileWithHttp -Context $Context -Uri $url -OutFile $archivePath
                if ($dl.Ok) {
                    $check = Test-WinstFileIntegrity -Context $Context -FilePath $archivePath -FileDecl $files[0] `
                        -FileUrl $url -SourceVersion $sourceVersion
                    if (-not $check.Ok) {
                        Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
                        $result.Error = ('{0} 校验失败：{1}' -f $archiveName, $check.Error)
                        return $result
                    }
                    Set-WinstFilePlanIntegrityFromCheck -FilePlan $filePlan -Check $check
                    Update-WinstPackageCacheIndex -Context $Context -Id $selfId -Plans $packagePlans `
                        -PrevEntry $prevEntry -Version $sourceVersion -DownloadedNames @($archiveName)

                    $result.ArchivePath = $archivePath
                    $result.Downloaded = $true
                    $result.Resolved = $true
                    $result.Ok = $true
                    return $result
                }

                $errorText = ('下载 {0} 失败：{1}' -f $archiveName, $dl.Error)
            }
        } else {
            $errorText = 'winst 的软件定义里没有可下载的安装包'
        }
    } elseif ($offline) {
        $errorText = '严格离线模式不能下载 winst 更新'
    } else {
        $errorText = '无法取得 winst 的软件定义'
    }

    # ------------------------------------------------------- ③ 仅引导安装
    if ($RequireDownload) {
        if (-not $errorText) { $errorText = '没有取得可验证的 winst 更新包' }
        $result.Error = $errorText
        return $result
    }

    if ((Get-WinstState -Name WinstScriptPath) -and
        (Test-Path -LiteralPath (Get-WinstState -Name WinstScriptPath) -PathType Leaf)) {
        $result.FallbackSourcePath = (Get-WinstState -Name WinstScriptPath)
        $result.Ok = $true
        if (-not $Quiet) {
            Write-Host ('    提示: 改用当前完整运行树作为 winst 的安装来源（{0}）' -f (Split-Path -Leaf $result.FallbackSourcePath)) -ForegroundColor DarkGray
        }
        return $result
    }

    if (-not $errorText) { $errorText = '既没有可下载的 winst 安装包，也读不到当前运行的脚本' }
    $result.Error = $errorText
    return $result
}
