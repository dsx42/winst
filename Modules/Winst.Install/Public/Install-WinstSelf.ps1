#Requires -Version 5.1
<#
    Install-WinstSelf.ps1  (Winst.Install / Public)

    安装或更新 winst 自身。

    包形态
    ------
    winst 是一个目录（winst.ps1 + winst.cmd + Modules\），
    以固定文件名（winst.zip，不带版本号）的 release zip 分发：

        type: portable  mainExe = winst.cmd

    两种包来源
    ----------
    (1) 软件源（常规路径）：解析 id "winst" 的清单条目，下载 release zip 并校验。

    (2) 本地包，通过 `-FromPath`（一行安装脚本用的就是这条）：

            winst install winst --from D:\downloads\winst.zip

        不查软件源、不联网、不解析依赖。包已经在磁盘上，
        只需要它自己的定义。这样就避免了「装 winst 需要先能访问软件源」的自锁，
        而全新机器恰恰还没有可访问的源。

    为什么本地路径也要比较版本
    --------------------------
    重跑安装脚本必须是「更新」，既不能静默什么都不做，也不能静默降级：

        包更新   -> 安装（更新）
        版本相同 -> 提示「已是最新」，不动任何文件
        包更旧   -> 拒绝，除非显式 --force

    为什么不复用 Invoke-WinstAppInstall
    ----------------------------------
    两个原因，都是刻意的：

    - 引导顺序。Confirm-WinstSelf 在任何软件安装之前运行。
      Invoke-WinstAppInstall 会调 Confirm-WinstDownloadEngine，
      冷启动（还没有引擎）时会递归回到自安装路径。
    - 目标重叠。安装目录常常就是 winst 当前运行的目录。
      Invoke-WinstAppInstall 的 clean 绿色版模式会先删目标目录再解压，
      那会删掉正在运行进程的文件。本函数先解压到暂存目录再合并，
      运行中的副本直到合并那一步才被改动。

    更新时保留
    ----------
    lists\ 与 *.list：用户数据，不属于任何 release。release 未提供的其它项会被删除，
    以免较旧版本残留的模块
    version cannot linger and shadow new ones.

    .OUTPUTS
        @{ Ok; Error; Installed; Updated; UpToDate; Version; Exe }
#>
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
        @{ Ok; Error; Installed; Updated; UpToDate; Version; Exe }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet,
        [switch]$ForceUpdate,
        [string]$FromPath = ''
    )

    $result = @{
        Ok        = $false
        Error     = ''
        Installed = $false
        Updated   = $false
        UpToDate  = $false
        Version   = ''
        Exe       = ''
    }

    $selfId = 'winst'
    $installDir = Join-WinstPath $Context.InstallRoot $selfId
    $launcherPath = Join-WinstPath $installDir 'winst.cmd'

    $exists = Test-Path -LiteralPath $launcherPath -PathType Leaf

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) {
        $result.Error = '预览模式不会安装 / 更新 winst 自身'
        return $result
    }

    # ------------------------------------------------- 本地包（--from）
    if ($FromPath) {
        $sourceVersion = ''
        $versionRead = Get-WinstSelfSourceVersion -Path $FromPath
        if (-not $versionRead.Ok) {
            $result.Error = [string]$versionRead.Error
            return $result
        }
        $sourceVersion = [string]$versionRead.Version

        $installedVersion = ''
        $ledger = Get-WinstInstalledApp -State (Read-WinstState -InstallRoot $Context.InstallRoot).State -Id $selfId
        if ($ledger) { $installedVersion = Get-EntryString -Entry $ledger -Key 'version' }

        if ($exists -and $installedVersion -and -not $ForceUpdate) {
            $comparison = Compare-WinstVersion -A $sourceVersion -B $installedVersion

            if ($comparison -eq 0) {
                $result.Ok = $true
                $result.UpToDate = $true
                $result.Version = $installedVersion
                $result.Exe = $launcherPath
                if (-not $Quiet) {
                    Write-Host ('    winst 已是最新版本（{0}），无需更新。' -f $installedVersion) -ForegroundColor DarkGray
                }
                return $result
            }

            if ($comparison -lt 0) {
                $result.Error = ('安装包版本 {0} 低于本机已安装的 {1}；如确需降级，请加 --force' -f $sourceVersion, $installedVersion)
                return $result
            }
        }

        $isUpdate = [bool]$exists
        $plan = New-WinstSelfPlan -Version $sourceVersion

        # 两种形态都接受：已解压目录直接复制，压缩包解压。
        # 按实际形态传参，调用方已有树时就不必再解压一次。
        $treeArgs = @{ InstallDir = $installDir; Quiet = [bool]$Quiet }
        if (Test-Path -LiteralPath $FromPath -PathType Container) {
            $treeArgs['SourceDir'] = $FromPath
        } else {
            $treeArgs['ArchivePath'] = $FromPath
        }

        $write = Set-WinstSelfTree @treeArgs
        if (-not $write.Ok) {
            $result.Error = [string]$write.Error
            return $result
        }

        $ledgerWrite = Register-WinstSelfLedger -Context $Context -Plan $plan -InstallDir $installDir `
            -Updated $isUpdate -Resolved $true -SourceVersion $sourceVersion -SourceName '' -Quiet:$Quiet

        $result.Ok = $true
        $result.Updated = $isUpdate
        $result.Installed = -not $exists
        $result.Version = [string]$ledgerWrite.Version
        $result.Exe = $launcherPath

        if (-not $Quiet) {
            $actionText = '已安装'
            if ($result.Updated) { $actionText = '已更新（重启 winst 后生效）' }
            Write-Host ('    winst {0}: {1}' -f $actionText, $installDir) -ForegroundColor DarkGray
        }

        return $result
    }

    # ------------------------------------------------------ 软件源
    if ($exists -and -not $ForceUpdate) {
        $result.Ok = $true
        $result.Exe = $launcherPath
        return $result
    }
    $isUpdate = [bool]($ForceUpdate -and $exists)

    # ① 软件定义 ② 安装包（release zip 或当前运行副本）
    $package = Get-WinstSelfPackageSource -Context $Context -Quiet:$Quiet -RequireDownload:$isUpdate
    if (-not $package.Ok) {
        $result.Error = [string]$package.Error
        return $result
    }

    # ③ 解压并合并
    # 包来源有两字段（见 Get-WinstSelfPackageSource）：ArchivePath = 下载到的
    # release zip（正常路径），FallbackSourcePath = 只能拿到运行中脚本时的兜底。
    # 这里必须按这两个真实字段名取，写错键名在 StrictMode 下会直接抛
    # 「找不到属性 SourcePath」，把自动安装 winst 打断（首次安装即失败）。
    $write = Set-WinstSelfTree -InstallDir $installDir -ArchivePath ([string]$package.ArchivePath) `
        -FallbackSourcePath ([string]$package.FallbackSourcePath) -Quiet:$Quiet
    if (-not $write.Ok) {
        $result.Error = [string]$write.Error
        return $result
    }

    # ④ 系统项 ⑤ 台账
    $ledger = Register-WinstSelfLedger -Context $Context -Plan $package.Plan -InstallDir $installDir `
        -Updated $isUpdate -Resolved ([bool]$package.Resolved) `
        -SourceVersion ([string]$package.SourceVersion) -SourceName ([string]$package.SourceName) -Quiet:$Quiet

    $result.Ok = $true
    $result.Updated = $isUpdate
    $result.Installed = -not $exists
    $result.Version = [string]$ledger.Version
    $result.Exe = $launcherPath

    if (-not $Quiet) {
        $actionText = '已安装'
        if ($result.Updated) { $actionText = '已更新（重启 winst 后生效）' }
        Write-Host ('    winst {0}: {1}' -f $actionText, $installDir) -ForegroundColor DarkGray
    }

    return $result
}
