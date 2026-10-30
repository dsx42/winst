#Requires -Version 5.1

function Initialize-WinstInstallContext {
    <#
    .SYNOPSIS
        安装前的上下文准备：条目字段、版本来源判定、① 取包判定（缓存计划）与台账读取。
    .DESCRIPTION
        把「软件定义里有什么」「主包要不要重新取」「缓存里哪些文件可以复用」「本机装没装」四件事一次算清，
        供后续决策矩阵 / 下载 / 安装各段直接使用。Error 非空时调用方应立即返回该结果。
    .OUTPUTS
        @{ Error; Id; DisplayName; Type; Version; InstallDir; PkgDir; Install; Files; VersionFromPackage;
           VersionFromCachedPackage; PlanFreshState; FreshMain; FreshMainReason; IsDownloadType; PrevEntry;
           Plans; NeedDownload; PrimaryTarget; CompanionDownloadCount; CompanionsOnly; Ledger }
    #>
    param([hashtable]$Context, $Plan, [switch]$DownloadOnly, [switch]$Quiet, $Result)

    $id = Get-EntryString -Entry $Plan -Key 'id'
    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = $id }
    $type = (Get-EntryString -Entry $Plan -Key 'type').Trim().ToLowerInvariant()
    $version = Get-EntryString -Entry $Plan -Key 'version'
    if (-not $id) { return @{ Error = '软件定义缺少 id' } }
    # id 会拼成 installRoot\<id> 与 pkgDir\<id>，清理模式还会递归删除该目录：
    # 含分隔符 / .. / 非法字符的 id 会越界删除或写到安装根之外，必须在安装入口处拒绝
    if (-not (Test-WinstSafePathSegment -Name $id)) {
        return @{ Error = ('软件定义里的 id 不合法（只能是单个目录名，且不能是 . / .. 或含非法字符）：{0}' -f $id) }
    }

    # 在任何下载 / 清理之前检查磁盘身份及台账；Windows 不能为 Foo / foo 提供独立目录。
    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    try { Assert-WinstAppIdentityAvailable -Context $Context -Id $id -State $stateRead.State -Index $indexRead.Index }
    catch { return @{ Error = $_.Exception.Message } }

    $installDir = Join-WinstPath $Context.InstallRoot $id
    $pkgDir = Join-WinstPath $Context.PkgDir $id
    $Result.InstallDir = $installDir

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) {
        return @{ Error = ('{0} 的软件定义里没有可下载的文件' -f $displayName) }
    }

    $nameError = Get-WinstDuplicateDownloadNameError -Files $files
    if ($nameError) { return @{ Error = $nameError } }

    # versionFromPackage（清单里是 source.versionFrom: "package"）：清单 / 接口都拿不到版本号时，从已下载的主包文件信息里取
    $versionFromPackage = Get-EntryBool -Entry $Plan -Key 'versionFromPackage'
    # 版本号取自「缓存里那份包」（不是软件源）——它不代表软件源当前提供的那一份，只能当展示值，不能当判据。
    # 解析锁里带着 versionFromCache 标记时必须沿用：否则主包重新取回后，「重读包内版本」那一步会被跳过，
    # 把上一次那份包的版本当成这一次的——消息与缓存索引都会留下错误版本号
    $versionFromCachedPackage = [bool](Get-EntryBool -Entry $Plan -Key 'versionFromCache')
    # 解析锁里的远端新鲜度结论：versionFromPackage 条目据此决定「主包要不要重新取」——
    # unchanged（远端无新包）时缓存里那份就是软件源当前这一份，安装 / 更新直接沿用缓存、按缓存版本决策；
    # changed（远端有新包）/ unknown（HEAD 没比出结论）才重新取包；明确的下载操作（DownloadOnly）始终重新下载
    $planFreshState = [string](Get-EntryString -Entry $Plan -Key 'remoteFresh')
    $freshMain = [bool]$versionFromPackage
    if ($freshMain -and -not $DownloadOnly -and $planFreshState -ieq 'unchanged') { $freshMain = $false }
    $freshMainReason = ''
    if ($freshMain) {
        if ($planFreshState -ieq 'changed') { $freshMainReason = '远端有新包（HEAD 检测），将重新下载安装包' }
        else { $freshMainReason = '无法确认远端文件是否变化，将重新取包核对版本' }
    }
    if (-not $version -and $versionFromPackage) {
        $mainName = Get-EntryString -Entry $files[0] -Key 'name'
        if (-not $mainName) { $mainName = Get-FileNameFromUrl -Url (Get-EntryString -Entry $files[0] -Key 'url') }
        # 派生路由：声明 packageVersion 的条目用 7-Zip 读包内结构，否则读主包文件信息
        $derivedResult = Get-WinstPackageDerivedVersion -Context $Context -PkgDir $pkgDir -Plan $Plan -FileName $mainName
        if ($derivedResult.Ok) {
            $derived = [string]$derivedResult.Version
            # 包内派生的版本就是「软件源里的版本」→ 套源侧规则 source.versionRewrite
            $rules = @(Get-EntryArray -Entry $Plan -Key 'sourceVersionRewrite')
            if ($rules.Count -gt 0) {
                $rewritten = Get-WinstRewrittenVersion -Version $derived -Rules $rules
                if ($rewritten) { $derived = $rewritten }
            }
            $version = $derived
            $versionFromCachedPackage = $true
            # 解析锁里的条目是 PSObject（不能 ['key'] 赋值，见 Set-EntryValue）：统一走设置助手
            $null = Set-EntryValue -Entry $Plan -Key 'version' -Value $derived
        } elseif ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            Write-Host ('  [verbose] 包内版本派生未成功（{0}），后续按既有记录继续' -f [string]$derivedResult.Error) -ForegroundColor DarkGray
        }
    }

    $isDownloadType = ($type -eq 'download') -or $DownloadOnly

    # —— ① 取包判定（缓存里已有需要的文件 → 跳过下载，绝不重复下载）——
    # 放在已装检测之前：版本相同时也需要知道「配套文件有没有变化」
    $index = $indexRead.Index
    if ($indexRead.Error -and -not $Quiet) { Write-Host ('  提示: {0}' -f $indexRead.Error) -ForegroundColor DarkYellow }
    $prevEntry = $null
    if ($index.Contains($id)) { $prevEntry = $index[$id] }

    # -CheckValidators：安装 / 更新 / 仅下载都要按 files[].refresh 判定「缓存里那份还算不算数」
    # -FreshMain：版本号取自主包文件信息的条目——unchanged（远端无新包）沿用缓存，changed / unknown 才重新取
    # -DownloadOnly：type: download 的条目（或按仅下载操作）——主包版本优先判定
    $plans = @(Get-WinstPackageFilePlans -Context $Context -Index $index -Id $id -Files $files -CheckValidators `
        -FreshMain:$freshMain -FreshMainReason:$freshMainReason -DownloadOnly:$isDownloadType -SourceVersion $version)
    if ($plans.Count -eq 0) {
        return @{ Error = ('{0} 的软件定义里没有可下载的文件' -f $displayName) }
    }
    $needDownload = $false
    # 注意：循环变量不能叫 $plan——PowerShell 变量名不区分大小写，会覆盖参数 $Plan（软件清单条目）
    foreach ($filePlan in $plans) { if ($filePlan['NeedDownload']) { $needDownload = $true; break } }
    $primaryTarget = [string]$plans[0]['Target']
    # 需要重取的只有配套文件吗？主包命中缓存、第 2 条起有变化 → 走「仅配套文件更新」
    $mainNeedsDownload = [bool]$plans[0]['NeedDownload']
    $companionDownloadCount = 0
    for ($planIndex = 1; $planIndex -lt $plans.Count; $planIndex++) {
        if ($plans[$planIndex]['NeedDownload']) { $companionDownloadCount++ }
    }
    $companionsOnly = [bool]($companionDownloadCount -gt 0 -and -not $mainNeedsDownload)

    $state = $stateRead.State
    if ($stateRead.Error -and -not $Quiet) { Write-Host ('  提示: {0}' -f $stateRead.Error) -ForegroundColor DarkYellow }
    $ledger = Get-WinstInstalledApp -State $state -Id $id

    return @{
        Error = ''; Id = $id; DisplayName = $displayName; Type = $type; Version = $version
        InstallDir = $installDir; PkgDir = $pkgDir; Install = $install; Files = $files
        VersionFromPackage = $versionFromPackage; VersionFromCachedPackage = $versionFromCachedPackage
        PlanFreshState = $planFreshState; FreshMain = $freshMain; FreshMainReason = $freshMainReason
        IsDownloadType = $isDownloadType; PrevEntry = $prevEntry; Plans = $plans; NeedDownload = $needDownload
        PrimaryTarget = $primaryTarget; CompanionDownloadCount = $companionDownloadCount
        CompanionsOnly = $companionsOnly; Ledger = $ledger
    }
}
