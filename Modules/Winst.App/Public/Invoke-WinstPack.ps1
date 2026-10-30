#Requires -Version 5.1

function Invoke-WinstPack {
    <#
    .SYNOPSIS
        菜单「制作U盘安装包」：把安装清单里的软件包（含两个引擎包）复制进 U 盘套件。
    .DESCRIPTION
        步骤：
          ① 选清单后**先列出清单里的软件**（状态 / 软件源 / 依赖，与「查看清单」同一口径），
             再收集它们的安装包 + 两个引擎包（FluxDown-CLI / 7-Zip-CLI）；
             缺包时先列出缺包清单并询问「是否现在联网下载补齐」，答否就跳过这些项继续制作；
          ② 按 <dir>\apps\<id>\ 复制包文件，并生成只含相关条目的套件索引 <dir>\apps\winst.json：
             **版本相同才跳过**；U 盘里是旧版本时先清掉该软件的旧目录再整份复制；
          ③ 复制脚本本体、本地清单、软件源列表与各源清单缓存（apps\manifests\）；
          ④ **只复制本次选中的那一份**清单文件到 <dir>\lists\，在套件根目录生成 winst.cmd（不生成 README.txt）。
        只动本次涉及的软件目录，不删除其它软件的既有内容；`--dry-run` 全链路只展示不落盘。
        本函数只做编排，各步骤由 select / show / copy 系列函数承担。
    .OUTPUTS
        @{ Ok; Cancelled; Error; TargetDir; Copied; Skipped; Missing; Downloaded }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$ListPath = '',
        [string]$TargetDir = '',
        # CLI `bundle pack --skip-missing`：缺包时**不联网补齐**，直接跳过这些软件
        [switch]$SkipMissing,
        # CLI 调用：不询问（缺包按 SkipMissing 处理；确认步骤由调用方负责）
        [switch]$NonInteractive
    )

    $result = @{ Ok = $false; Cancelled = $false; Error = ''; TargetDir = ''; Copied = 0; Skipped = 0; Missing = 0; Downloaded = 0 }

    Write-Section '制作U盘安装包'

    if (-not $Context.PkgDir) {
        Write-Host ''
        Write-Host '  没有可用的安装包位置，无法收集安装包。' -ForegroundColor Red
        return $result
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)
    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)

    # —— ① 选择安装清单 ——
    $pick = Select-WinstBundleList -Context $Context -ListPath $ListPath
    if (-not $pick.Ok) {
        if ($pick.Cancelled) {
            if (-not (Get-WinstState -Name WinstQuitRequested)) {
                Write-Host '  已返回。' -ForegroundColor DarkGray
                $null = Set-WinstState -Name WinstSkipMenuPause -Value ($true)
            }
        }
        return $result
    }
    $ListPath = [string]$pick.ListPath
    $loaded = $pick.Loaded
    $lookup = $loaded.Lookup
    $sourceCacheIndex = $pick.SourceCacheIndex

    # —— ② 列出清单软件 ③ 目标目录 ④ 需求清单 ——
    $TargetDir = Resolve-WinstBundleTarget -Context $Context -TargetDir $TargetDir -ListPath $ListPath -Items $loaded.Items
    $result.TargetDir = $TargetDir

    $plan = @(Get-WinstPackItemList -Context $Context -Lookup $lookup -Items $loaded.Items)
    Write-WinstBundleRequirement -Items $loaded.Items -Plan $plan -TargetDir $TargetDir

    # —— ⑤ 缺包检查（只查本地缓存，不联网） ——
    $missing = Resolve-WinstBundleMissingPackages -Context $Context -Plan $plan -Lookup $lookup `
        -Offline:$offline -DryRun:$dryRun -SkipMissing:$SkipMissing -Yes:$yes -NonInteractive:$NonInteractive
    $needDownload = @($missing.NeedDownload)
    $noSource = @($missing.NoSource)
    $result.Downloaded = [int]$missing.Downloaded
    if ([int]$missing.Downloaded -gt 0) {
        # 重新读取目录、索引和列表条目，不能继续引用下载前的缓存快照。
        $loaded = Get-WinstListItems -Context $Context -Path $ListPath
        if (-not $loaded.Ok) { $result.Error = [string]$loaded.Error; return $result }
        $lookup = $loaded.Lookup
        $sourceCacheIndex = $lookup['CacheIndex']
        $plan = @(Get-WinstPackItemList -Context $Context -Lookup $lookup -Items $loaded.Items)
    }

    # —— ⑥ 制作计划确认 ——
    $confirm = Show-WinstBundlePlan -TargetDir $TargetDir -Plan $plan -DryRun:$dryRun -Yes:$yes -NonInteractive:$NonInteractive
    if ($confirm.Empty) { return $result }   # 一个可复制的包都没有：原实现直接返回（不置 Cancelled）
    if ($confirm.Cancelled) {
        $result.Cancelled = $true
        return $result
    }

    # —— ⑦ 复制安装包 + 生成套件索引 ——
    $kitAppsDir = Join-WinstPath $TargetDir 'apps'
    $packages = Copy-WinstBundlePackages -CopyItems $confirm.CopyItems -KitAppsDir $kitAppsDir `
        -SourceCacheIndex $sourceCacheIndex -TargetDir $TargetDir -DryRun:$dryRun
    $copied = [int]$packages.Copied
    $skipped = [int]$packages.Skipped

    # —— ⑧ 复制清单数据 / 脚本 / 清单文件，并生成启动器 ——
    $support = Copy-WinstBundleSupportFiles -Context $Context -TargetDir $TargetDir -KitAppsDir $kitAppsDir `
        -KitIndex $packages.KitIndex -ListPath $ListPath -DryRun:$dryRun
    if (-not $support.Ok) {
        $result.Error = [string]$support.Error
        Write-Host ('  制作U盘安装包失败: {0}' -f $result.Error) -ForegroundColor Red
        return $result
    }

    # —— ⑨ 汇总 ——
    $missingCount = $needDownload.Count + $noSource.Count
    if (@($packages.Errors).Count -gt 0) {
        $result.Error = ('部分安装包复制失败：{0}' -f (@($packages.Errors) -join '；'))
        Write-Host ('  制作U盘安装包失败: {0}' -f $result.Error) -ForegroundColor Red
    } else {
        Write-WinstBundleSummary -TargetDir $TargetDir -DryRun:$dryRun -Copied $copied -Skipped $skipped `
            -MissingCount $missingCount -ManifestCopied ([int]$support.ManifestCopied) -ListFileCount ([int]$support.ListFileCount)
        $result.Ok = $true
    }
    $result.Copied = $copied
    $result.Skipped = $skipped
    $result.Missing = $missingCount
    return $result
}
