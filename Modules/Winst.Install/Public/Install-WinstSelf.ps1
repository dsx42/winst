#Requires -Version 5.1
function Install-WinstSelf {
    <#
    .SYNOPSIS
        安装或更新 winst 自身（zip 分发的绿色版结构）。

    .PARAMETER FromPath
        用这个包安装，不走软件源。接受 release zip 或已解压目录。
        完全跳过来源解析、下载与依赖处理。

    .PARAMETER ForceUpdate
        目标已是同版本、或包比已装版本更旧（降级）时也重装。

    .OUTPUTS
        @{ Ok; Error; Updated; UpToDate; Version }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$ForceUpdate,
        [string]$FromPath = ''
    )

    $result = @{
        Ok        = $false
        Error     = ''
        Updated   = $false
        UpToDate  = $false
        Version   = ''
    }

    $selfId = 'winst'
    try { Assert-WinstAppIdentityAvailable -Context $Context -Id $selfId }
    catch { $result.Error = $_.Exception.Message; return $result }
    $installDir = Join-WinstPath $Context.InstallRoot $selfId
    $launcherPath = Join-WinstPath $installDir 'winst.cmd'

    $exists = Test-Path -LiteralPath $launcherPath -PathType Leaf

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) {
        $result.Error = '预览模式不会安装 / 更新 winst 自身'
        return $result
    }

    $treeArgs = @{ InstallDir = $installDir }
    $isUpdate = [bool]$exists
    $packageLock = $null
    try {
        if ($FromPath) {
            $versionRead = Get-WinstSelfSourceVersion -Path $FromPath
            if (-not $versionRead.Ok) {
                $result.Error = [string]$versionRead.Error
                return $result
            }
            $sourceVersion = [string]$versionRead.Version

            if ((Test-Path -LiteralPath $installDir -PathType Container) -and -not $ForceUpdate) {
                $installedRead = Get-WinstSelfSourceVersion -Path $installDir
                if (-not $installedRead.Ok -or -not $installedRead.Version) {
                    $result.Error = ('无法识别现存 winst 程序树的版本，未覆盖文件；请核对目录，确需重装时加 --force：{0}' -f $installedRead.Error)
                    return $result
                }
                $installedVersion = [string]$installedRead.Version
                $comparison = Compare-WinstVersion -A $sourceVersion -B $installedVersion

                if ($comparison -eq 0 -and $exists) {
                    $result.Ok = $true
                    $result.UpToDate = $true
                    Write-Host ('    winst 已是最新版本（{0}），无需更新。' -f $installedVersion) -ForegroundColor DarkGray
                    return $result
                }

                if ($comparison -lt 0) {
                    $result.Error = ('安装包版本 {0} 低于本机已安装的 {1}；如确需降级，请加 --force' -f $sourceVersion, $installedVersion)
                    return $result
                }
            }

            $plan = New-WinstSelfPlan

            # 两种形态都接受：已解压目录直接复制，压缩包解压。
            # 按实际形态传参，调用方已有树时就不必再解压一次。
            if (Test-Path -LiteralPath $FromPath -PathType Container) {
                $treeArgs['SourceDir'] = $FromPath
            } else {
                $treeArgs['ArchivePath'] = $FromPath
            }

            $sourceName = ''
            $resolved = $true
        } else {
            if ($exists -and -not $ForceUpdate) {
                $result.Ok = $true
                return $result
            }
            if (-not ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)) {
                try { $packageLock = Enter-WinstPackageLock -PkgDir $Context.PkgDir -Id $selfId }
                catch { $result.Error = $_.Exception.Message; return $result }
            }
            $package = Get-WinstSelfPackageSource -Context $Context -RequireDownload:$isUpdate
            if (-not $package.Ok) {
                $result.Error = [string]$package.Error
                return $result
            }
            $treeArgs['ArchivePath'] = [string]$package.ArchivePath
            $treeArgs['FallbackSourcePath'] = [string]$package.FallbackSourcePath
            $plan = $package.Plan
            $sourceVersion = [string]$package.SourceVersion
            $sourceName = [string]$package.SourceName
            $resolved = [bool]$package.Resolved
        }

        $write = Set-WinstSelfTree @treeArgs
        if (-not $write.Ok) {
            $result.Error = [string]$write.Error
            return $result
        }
    } finally {
        if ($null -ne $packageLock) { $packageLock.Dispose() }
    }
    $ledger = Register-WinstSelfLedger -Context $Context -Plan $plan -InstallDir $installDir `
        -Updated $isUpdate -Resolved $resolved `
        -SourceVersion $sourceVersion -SourceName $sourceName

    $result.Ok = $true
    $result.Updated = $isUpdate
    $result.Version = [string]$ledger.Version

    $actionText = '已安装'
    if ($result.Updated) { $actionText = '已更新（重启 winst 后生效）' }
    Write-Host ('    winst {0}: {1}' -f $actionText, $installDir) -ForegroundColor DarkGray

    return $result
}
