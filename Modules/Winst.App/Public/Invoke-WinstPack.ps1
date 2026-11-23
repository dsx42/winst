#Requires -Version 5.1

function Invoke-WinstPack {
    <#
    .SYNOPSIS
        菜单「制作U盘安装包」：收集引擎、winst 和清单软件及其依赖，制作 U 盘套件。
    .DESCRIPTION
        步骤：
          ① 选清单和目标目录后列出清单里的软件（状态 / 软件源 / 依赖，与「查看清单」同一口径），
             再按安装顺序收集所需包；
             制作完整套件时刷新软件源并核对每个安装包，下载缺失或需要更新的文件；
          ② 按 <dir>\apps\<id>\ 复制包文件，并更新相关条目的套件索引 <dir>\apps\winst.json：
             同版本且摘要相同的文件可跳过，版本不同或有过时文件时替换旧目录；
          ③ 复制脚本本体、本地清单、软件源列表与各源清单缓存（apps\manifests\）；
          ④ 在 <dir>\lists\ 生成与收包计划同序的安装清单，在套件根目录生成 winst.cmd（不生成 README.txt）。
        只动本次涉及的软件目录，不删除其它软件的既有内容；`--dry-run` 全链路只展示不落盘。
        本函数只做编排，各步骤由 select / show / copy 系列函数承担。
    .OUTPUTS
        @{ Ok; Cancelled; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$ListPath = '',
        [string]$TargetDir = '',
        # CLI `bundle pack --skip-missing`：按本地缓存制作，跳过缺包项。
        [switch]$SkipMissing,
        # CLI 调用：不询问；只有显式 SkipMissing 才允许部分套件。
        [switch]$NonInteractive
    )

    $result = @{ Ok = $false; Cancelled = $false; Error = '' }

    Write-Section '制作U盘安装包'

    if (-not $Context.PkgDir) {
        Write-Host ''
        Write-Host '  没有可用的安装包位置，无法收集安装包。' -ForegroundColor Red
        return $result
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)
    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)

    $requireCurrent = -not $offline -and -not $dryRun -and -not $SkipMissing
    if ($offline -and -not $dryRun -and -not $SkipMissing) {
        $result.Error = '制作完整套件需要联网检查最新版本。离线仅可用 --skip-missing 按本地缓存制作。'
        return $result
    }

    # —— ① 选择安装清单 ——
    if ($ListPath -or $NonInteractive) {
        $pick = Resolve-WinstListFileForCli -Context $Context -Text $ListPath
        if (-not $pick.Ok) { return $result }
    } else {
        $pick = Select-WinstListFile -Context $Context -NoCreate
        if (-not $pick.Ok) {
            if (-not (Get-WinstState -Name WinstQuitRequested)) {
                Write-Host '  已返回。' -ForegroundColor DarkGray
                $null = Set-WinstState -Name WinstSkipMenuPause -Value ($true)
            }
            return $result
        }
    }
    $ListPath = [string]$pick.Path
    try { Assert-WinstSafeWritePath -Path $ListPath }
    catch { $result.Error = $_.Exception.Message; return $result }

    # 列出软件可能刷新来源，先确认目标清单不会覆盖输入。
    try {
        $TargetDir = Resolve-WinstBundleTarget -Context $Context -TargetDir $TargetDir
    } catch [System.ArgumentException], [System.NotSupportedException], [System.IO.PathTooLongException], [System.Management.Automation.ProviderNotFoundException], [System.Management.Automation.DriveNotFoundException] {
        $result.Error = ('目标目录不合法：{0}' -f $_.Exception.Message)
        return $result
    }
    if (-not $TargetDir) { $result.Cancelled = $true; return $result }
    $listTarget = Join-WinstPath (Join-WinstPath $TargetDir 'lists') (Split-Path -Leaf $ListPath)
    if ([IO.Path]::GetFullPath($ListPath) -ieq $listTarget) {
        $result.Error = '套件安装清单不能覆盖用于收包的输入清单。'
        return $result
    }
    $loaded = Get-WinstListItems -Context $Context -Path $ListPath
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return $result
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }
    if (@($loaded.BadLines).Count -gt 0) {
        Write-Host ('  安装清单含无法解析的行，请先修正：{0}' -f (@($loaded.BadLines) -join '；')) -ForegroundColor Red
        return $result
    }
    if (@($loaded.Items).Count -eq 0) {
        Write-Host ''
        Write-Host '  这份安装清单是空的。' -ForegroundColor Yellow
        Write-Host ('  清单文件: {0}' -f $ListPath) -ForegroundColor DarkGray
        Write-Host '  请先到「高级功能 → 管理安装清单」里新建或编辑清单，挑选软件。' -ForegroundColor DarkGray
        return $result
    }

    $lookup = $loaded.Lookup
    Write-Host ''
    Write-Host ('  安装清单: {0}' -f $ListPath) -ForegroundColor Gray
    Show-WinstListContent -Context $Context -Items $loaded.Items -StateRead $lookup.StateRead

    $requirements = Get-WinstPackItemList -Context $Context -Lookup $lookup -Items $loaded.Items
    if ($requireCurrent) {
        $refreshedIds = New-WinstOrdinalDictionary
        while ($true) {
            $ids = @(foreach ($item in @($requirements.Plan)) {
                $id = [string]$item['Id']
                if (-not $refreshedIds.Contains($id)) { $id }
            })
            if (-not $ids.Count) { break }

            $refresh = Update-WinstStaleSources -Context $Context -Force -OnlyIds $ids
            Write-WinstRefreshErrors -Errors $refresh.Errors
            if ($refresh.Failed) {
                $result.Error = '软件源刷新失败，无法确认套件使用的安装包是最新版本。'
                return $result
            }
            foreach ($id in $ids) { $refreshedIds[$id] = $true }
            $loaded = Get-WinstListItems -Context $Context -Path $ListPath
            if (-not $loaded.Ok) { $result.Error = [string]$loaded.Error; return $result }
            $lookup = $loaded.Lookup
            $requirements = Get-WinstPackItemList -Context $Context -Lookup $lookup -Items $loaded.Items
        }
    }
    $plan = @($requirements.Plan)
    Write-WinstBundleRequirement -Items $loaded.Items -Plan $plan -TargetDir $TargetDir

    # —— ⑤ 核对并更新套件所需的包，再检查本地文件 ——
    if ($requireCurrent) {
        $packageErrors = @()
        foreach ($item in $plan) {
            $chosen = $item['PlanEntry']
            if (-not $chosen) { continue }
            $errorText = Get-EntryString -Entry $chosen['Plan'] -Key 'lastResolveError'
            if (-not $errorText) {
                try {
                    $one = Invoke-WinstAppInstall -Context $Context -Plan $chosen['Plan'] -SourceName ([string]$chosen['Source']) `
                        -DownloadOnly -RequireCurrent -Quiet
                    if ($one.Ok) {
                        if ($one.Downloaded) {
                            Write-Host ('  {0}' -f $one.Message) -ForegroundColor Green
                        }
                        continue
                    }
                    $errorText = [string]$one.Error
                } catch { $errorText = $_.Exception.Message }
            }
            if (-not $errorText) { $errorText = '无法确认安装包是最新版本' }
            $packageErrors += ('{0}: {1}' -f $item['Id'], $errorText)
        }
        if ($packageErrors.Count) {
            foreach ($errorText in $packageErrors) { Write-Host ('  失败: {0}' -f $errorText) -ForegroundColor Red }
            $result.Error = '未能确认所有安装包为最新版本，已停止制作套件。'
            return $result
        }

        $loaded = Get-WinstListItems -Context $Context -Path $ListPath
        if (-not $loaded.Ok) { $result.Error = [string]$loaded.Error; return $result }
        $lookup = $loaded.Lookup
    }

    $missingCount = (Resolve-WinstBundleMissingPackages -Context $Context -Plan $plan -Lookup $lookup) + @($requirements.Errors).Count
    foreach ($errorText in @($requirements.Errors)) { Write-Host ('  依赖不完整: {0}' -f $errorText) -ForegroundColor DarkYellow }
    if ($missingCount -gt 0 -and -not $SkipMissing) {
        $result.Error = '套件不完整，请补齐缺包和依赖，或显式指定 --skip-missing 制作部分套件。'
        return $result
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
    $packages = Copy-WinstBundlePackages -Context $Context -CopyItems $confirm.CopyItems -KitAppsDir $kitAppsDir `
        -SourceCacheIndex $lookup.CacheIndex -TargetDir $TargetDir -DryRun:$dryRun
    $copied = [int]$packages.Copied
    $skipped = [int]$packages.Skipped

    # —— ⑧ 复制清单数据 / 脚本 / 清单文件，并生成启动器 ——
    $support = Copy-WinstBundleSupportFiles -Context $Context -TargetDir $TargetDir -KitAppsDir $kitAppsDir `
        -ListTarget $listTarget -CommentLines $loaded.CommentLines -Plan $plan -DryRun:$dryRun
    if (-not $support.Ok) {
        $result.Error = [string]$support.Error
        return $result
    }

    # —— ⑨ 汇总 ——
    if (@($packages.Errors).Count -gt 0) {
        $result.Error = ('部分安装包复制失败：{0}' -f (@($packages.Errors) -join '；'))
    } else {
        Write-WinstBundleSummary -TargetDir $TargetDir -DryRun:$dryRun -Copied $copied -Skipped $skipped `
            -MissingCount $missingCount -ManifestCopied ([int]$support.ManifestCopied)
        $result.Ok = $true
    }
    return $result
}
