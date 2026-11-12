#Requires -Version 5.1

function Install-WinstEngine {
    <#
    .SYNOPSIS
        引导安装引擎条目（FluxDown-CLI / 7-Zip-CLI）：IWR 下载 → 解压落地 → 写台账与缓存索引；
        `-ForceUpdate` 时引擎已存在也重新下载覆盖。
    .DESCRIPTION
        引擎引导包与 winst 自身包是仅有的两处允许用 Invoke-WebRequest 下载的地方；
        引擎专用目录按 portable 管理；无法直接解压 7-Zip 引导包时可能安装完整的系统 7-Zip。
        7-Zip 引导包有旧引擎时直接用旧引擎解压；没有时先尝试 tar，再借助系统安装版解压。
        找不到可用系统安装时用 /S 静默运行已下载的 EXE，安装结束后用系统 7-Zip 解压引导包并交付。
        取定义 / 下载与索引 / 解压落地 / 台账 各由独立函数承担。
    .OUTPUTS
        @{ Ok; Exe; Error; Installed; Updated }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Quiet,
        # 引擎已存在时也重新下载覆盖；
        # 自动更新（Update-WinstEngineIfOutdated）用，常规引导不传——引擎存在即直接返回
        [switch]$ForceUpdate
    )

    $result = @{ Ok = $false; Exe = ''; Error = ''; Installed = $false; Updated = $false }

    try { Assert-WinstAppIdentityAvailable -Context $Context -Id $Id }
    catch { $result.Error = $_.Exception.Message; return $result }

    $mainExe = Get-WinstEngineMainExe -Id $Id
    $existing = Get-WinstEngineExe -Context $Context -Id $Id
    if ($existing -and -not $ForceUpdate) {
        $result.Ok = $true
        $result.Exe = $existing
        return $result
    }
    if ($ForceUpdate -and $existing) { $result.Updated = $true }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) {
        $result.Error = ('离线模式下无法自动安装 {0}；请在联网机器上执行 bundle pack，或手动把引擎放到安装目录' -f $Id)
        return $result
    }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) {
        $result.Error = ('预览模式不会安装 {0}（仅展示将要执行的动作）' -f $Id)
        return $result
    }

    if (-not $Quiet) { Write-Host ('  正在准备 {0} …' -f $Id) -ForegroundColor Gray }

    $resolved = Resolve-WinstEnginePlan -Context $Context -Id $Id
    if (-not $resolved.Ok) {
        $result.Error = [string]$resolved.Error
        return $result
    }
    $plan = $resolved.Plan
    $planId = Get-EntryString -Entry $plan -Key 'id'
    try { Assert-WinstAppIdentityAvailable -Context $Context -Id $planId }
    catch { $result.Error = $_.Exception.Message; return $result }
    $downloadBlock = Get-EntryValue -Entry $plan -Key 'download' -Default $null
    $nameError = Get-WinstDuplicateDownloadNameError -Files @(Get-EntryArray -Entry $downloadBlock -Key 'files')
    if ($nameError) { $result.Error = $nameError; return $result }
    $installDir = Join-WinstPath $Context.InstallRoot $planId

    # ① 下载（引擎引导例外：IWR）+ 缓存索引 + 旧包清理
    $download = Invoke-WinstEngineDownload -Context $Context -Id $Id -Plan $plan -PlanId $planId -Quiet:$Quiet
    if (-not $download.Ok) {
        $result.Error = [string]$download.Error
        return $result
    }

    # ② 解压 ③ 复制 / 改名
    $layout = Expand-WinstEnginePackage -Context $Context -Id $Id -Plan $plan -InstallDir $installDir `
        -ArchivePath ([string]$download.PrimaryPath) -Quiet:$Quiet
    if (-not $layout.Ok) {
        $result.Error = [string]$layout.Error
        return $result
    }
    if ($mainExe) {
        $exePath = Join-WinstPath $installDir $mainExe
        if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
            $result.Error = ('安装完成后没有找到 {0}（{1}），请检查软件源里的主程序设置' -f $mainExe, $exePath)
            return $result
        }
        $result.Exe = $exePath
    }

    # ④ 台账只登记引擎专用目录
    Register-WinstEngineLedger -Context $Context -Plan $plan -PlanId $planId -InstallDir $installDir `
        -SourceName ([string]$resolved.Source)

    if (-not $Quiet) { Write-Host ('    {0} 已就绪: {1}' -f $Id, $result.Exe) -ForegroundColor DarkGray }

    $result.Ok = $true
    $result.Installed = $true
    return $result
}
