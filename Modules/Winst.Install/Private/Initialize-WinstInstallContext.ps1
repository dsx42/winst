#Requires -Version 5.1

function Initialize-WinstInstallContext {
    <#
    .SYNOPSIS
        安装前的上下文准备：条目字段、版本来源判定、① 取包判定（缓存计划）与台账读取。
    .DESCRIPTION
        把「软件定义里有什么」「主包要不要重新取」「缓存里哪些文件可以复用」「本机装没装」四件事一次算清，
        供后续决策矩阵 / 下载 / 安装各段直接使用。Error 非空时调用方应立即返回该结果。
    .OUTPUTS
        @{ Error; Plan; Id; DisplayName; Type; Version; InstallDir; PkgDir; Install; PlanFreshState; IsDownloadType; PrevEntry;
           Plans; NeedDownload; CompanionNames; CompanionsOnly; Ledger }
    #>
    param([hashtable]$Context, $Plan, [switch]$DownloadOnly, [switch]$RequireCurrent, [switch]$Quiet)

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
    if ($stateRead.Error -and -not $stateRead.Reset) { return @{ Error = [string]$stateRead.Error } }
    $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    try { Assert-WinstAppIdentityAvailable -Context $Context -Id $id -State $stateRead.State -Index $indexRead.Index }
    catch { return @{ Error = $_.Exception.Message } }

    $installDir = Join-WinstPath $Context.InstallRoot $id
    $pkgDir = Join-WinstPath $Context.PkgDir $id

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) {
        return @{ Error = ('{0} 的软件定义里没有可下载的文件' -f $displayName) }
    }

    $nameError = Get-WinstDuplicateDownloadNameError -Files $files
    if ($nameError) { return @{ Error = $nameError } }

    # source.version.from 为 package 时从下载包取版，source.version.package.file 可指定从附件取版。
    $versionFromPackage = Get-EntryBool -Entry $Plan -Key 'versionFromPackage'
    # 解析锁里的远端新鲜度结论：versionFromPackage 条目据此决定「主包要不要重新取」——
    # unchanged（远端无新包）时缓存里那份就是软件源当前这一份，安装 / 更新直接沿用缓存、按缓存版本决策；
    # changed（远端有新包）/ unknown（文件比较没有结论）才重新取包
    $options = Get-WinstState -Name WinstOptions
    $offline = [bool]($options -and $options.Offline)
    $planFreshState = ''
    if (-not $offline) { $planFreshState = Get-EntryString -Entry $Plan -Key 'remoteFresh' }
    $unchangedMainHash = ''
    if ($versionFromPackage -and $planFreshState -ieq 'unchanged') {
        $unchangedMainHash = Get-EntryString -Entry $Plan -Key 'remoteFreshHash'
    }
    $freshMainReason = ''
    if ($versionFromPackage) {
        if ($planFreshState -ieq 'changed') { $freshMainReason = '远端有新包（文件比较），将重新下载安装包' }
        else { $freshMainReason = '无法确认远端文件是否变化，将重新取包核对版本' }
    }
    $isDownloadType = ($type -eq 'download') -or $DownloadOnly

    # —— ① 取包判定（缓存里已有需要的文件 → 跳过下载，绝不重复下载）——
    # 放在已装检测之前：版本相同时也需要知道「配套文件有没有变化」
    $index = $indexRead.Index
    if ($indexRead.Error -and -not $Quiet) { Write-Host ('  提示: {0}' -f $indexRead.Error) -ForegroundColor DarkYellow }
    $prevEntry = $null
    if ($index.Contains($id)) { $prevEntry = $index[$id] }

    $state = $stateRead.State
    if ($stateRead.Error -and -not $Quiet) { Write-Host ('  提示: {0}' -f $stateRead.Error) -ForegroundColor DarkYellow }
    $ledger = Get-WinstInstalledApp -State $state -Id $id
    # -FreshMain：版本号取自主包文件信息的条目——unchanged（远端无新包）沿用缓存，changed / unknown 才重新取
    # 安装与仅下载操作共用主包版本优先判定；FreshMain 时不能用缓存包版本命中
    $planArgs = @{
        Context = $Context; Id = $id; ManifestOrigin = Get-EntryString -Entry $Plan -Key 'manifestOrigin'; Files = $files
        FreshMain = $versionFromPackage; UnchangedMainHash = $unchangedMainHash; FreshMainReason = $freshMainReason
        RequireCurrent = $RequireCurrent
    }
    $plans = @(Get-WinstPackageFilePlans @planArgs -Index $index)
    if (-not $plans[0]['NeedDownload']) {
        $version = Get-EntryString -Entry $prevEntry -Key 'version'
    } elseif ($versionFromPackage) {
        $version = ''
    }
    if (-not $isDownloadType -and -not $plans[0]['NeedDownload'] -and $version) {
        try { $Plan = Get-WinstCachedInstallPlan -Context $Context -Plan $Plan -CachedVersion $version }
        catch { return @{ Error = $_.Exception.Message } }
        $install = Get-EntryValue -Entry $Plan -Key 'install'
    }

    $needDownload = $false
    # 注意：循环变量不能叫 $plan——PowerShell 变量名不区分大小写，会覆盖参数 $Plan（软件清单条目）
    foreach ($filePlan in $plans) { if ($filePlan['NeedDownload']) { $needDownload = $true; break } }
    $companionNames = @()
    $companionsOnly = $false

    if (-not $isDownloadType -and $plans.Count -gt 1) {
        # 复用已完成的取包计划，同时把缺失目标、落位规则变化计入附件更新；不重复规划或联网。
        $companionInfo = Get-WinstCompanionUpdateInfo -Context $Context -Plan $Plan -FilePlans $plans
        if ($companionInfo.Error) { return @{ Error = [string]$companionInfo.Error } }
        $companionNames = @($companionInfo.Names)
        $companionsOnly = [bool]$companionInfo.CompanionsOnly
    }

    return @{
        Error = ''; Plan = $Plan; Id = $id; DisplayName = $displayName; Type = $type; Version = $version
        InstallDir = $installDir; PkgDir = $pkgDir; Install = $install
        PlanFreshState = $planFreshState
        IsDownloadType = $isDownloadType; PrevEntry = $prevEntry; Plans = $plans; NeedDownload = $needDownload
        CompanionNames = $companionNames
        CompanionsOnly = $companionsOnly; Ledger = $ledger
    }
}
