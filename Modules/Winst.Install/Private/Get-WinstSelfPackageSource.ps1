#Requires -Version 5.1
<#
    Get-WinstSelfPackageSource.ps1  (Winst.Install / Private)

    取得用于安装或更新 winst 自身的安装包。

    支持两种包形态
    --------------
    1. release 压缩包（常规路径）
           清单里 id "winst" 条目的 files[0]：GitHub release 资产，固定名 winst.zip、不带版本号
           （releases/latest/download/winst.zip 永远指向最新版）
       通过下载引擎取包，并按 files[0].hashFile 声明的 .zip.sha512 校验。

    2. 当前运行树（脚本 + Modules + 启动器 + LICENSE；仅用于引导首次安装）
       备用启动脚本的位置从状态项 WinstScriptPath 读取。
       取不到压缩包时使用：离线，或仓库还没有发布任何版本。
       更新不得回退到它，否则「更新」会静默重装同一版本。

    .OUTPUTS
        @{ Ok; Error; ArchivePath; FallbackSourcePath; Resolved;
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
        @{ Ok; Error; ArchivePath; FallbackSourcePath; Resolved;
           Plan; SourceVersion; SourceName }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$RequireDownload
    )

    $selfId = 'winst'

    $result = @{
        Ok                 = $false
        Error              = ''
        ArchivePath        = ''
        FallbackSourcePath = ''
        Resolved           = $false
        Plan               = $null
        SourceVersion      = ''
        SourceName         = ''
    }

    # ---------------------------------------------------------- ① 软件定义
    $resolved = Get-WinstManifestAppPlan -Context $Context -Id $selfId -PreferSource (Get-WinstOfficialManifestName)

    $plan = $null
    $sourceName = ''

    if ($resolved.Ok) {
        $plan = $resolved.Plan
        $sourceName = [string]$resolved.Source
    }

    $result.Plan = $plan
    $result.SourceName = $sourceName

    # ------------------------------------------------------------ ② 取包
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)

    if ($plan -and -not $offline) {
        $download = Get-EntryValue -Entry $plan -Key 'download' -Default $null
        $files = @(Get-EntryArray -Entry $download -Key 'files')
        if ($files.Count -gt 0) {
            $pkgDir = Join-WinstPath $Context.PkgDir $selfId
            $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir -Ids @($selfId)
            $prevEntry = $null
            if ($cacheRead.Index.Contains($selfId)) { $prevEntry = $cacheRead.Index[$selfId] }
            $packagePlans = @(Get-WinstPackageFilePlans -Context $Context -Index $cacheRead.Index -Id $selfId -ManifestOrigin $sourceName `
                -Files $files)
            $download = Invoke-WinstPackageDownloadLoop -Context $Context -Plans $packagePlans -PkgDir $pkgDir -Id $selfId `
                -DisplayName $selfId -SourceName $sourceName -Plan $plan -PrevEntry $prevEntry -Bootstrap
            if ($download.Ok) {
                $result.Plan = $download.Plan
                $result.SourceVersion = $download.Version
                $result.ArchivePath = [string]$download.Plans[0]['Target']
                $result.Resolved = $true
                $result.Ok = $true
                return $result
            }

            $errorText = [string]$download.Error
            if (-not $download['DownloadFailed']) {
                $result.Error = $errorText
                return $result
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
        $result.Error = $errorText
        return $result
    }

    if ((Get-WinstState -Name WinstScriptPath) -and
        (Test-Path -LiteralPath (Get-WinstState -Name WinstScriptPath) -PathType Leaf)) {
        $result.FallbackSourcePath = (Get-WinstState -Name WinstScriptPath)
        $result.Ok = $true
        Write-Host ('    提示: 改用当前完整运行树作为 winst 的安装来源（{0}）' -f (Split-Path -Leaf $result.FallbackSourcePath)) -ForegroundColor DarkGray
        return $result
    }

    $result.Error = $errorText
    return $result
}
