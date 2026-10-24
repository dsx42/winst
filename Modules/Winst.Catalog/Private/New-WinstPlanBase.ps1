#Requires -Version 5.1

function New-WinstPlanBase {
    <#
    .SYNOPSIS
        生成解析锁条目的骨架：id / 名称 / 类型 / 分组 / 依赖，并做来源解析结果与类型的合法性校验。
    .OUTPUTS
        @{ Ok; Error; Plan; Notes }
    #>
    param(
        [string]$ManifestOrigin,
        $Entry,
        $Resolve
    )

    $id = Get-EntryString -Entry $Entry -Key 'id'
    $displayName = Get-EntryString -Entry $Entry -Key 'name'
    if (-not $displayName) { $displayName = $id }
    $typeRaw = (Get-EntryString -Entry $Entry -Key 'type').Trim().ToLowerInvariant()
    $type = ConvertTo-WinstEntryType -Type $typeRaw

    # 分组与依赖：group 是列表展示用的分组名；dependencies 是依赖的软件 id 列表
    # （按 Ordinal 去重、保持书写顺序；依赖 id 是否存在由解析依赖时校验并提示，见 Resolve-WinstDependencyOrder）。
    $groupName = (Get-EntryString -Entry $Entry -Key 'group').Trim()
    $dependencyIds = @()
    $dependencySeen = New-WinstOrdinalDictionary
    foreach ($depItem in @(Get-EntryArray -Entry $Entry -Key 'dependencies')) {
        if ($null -eq $depItem) { continue }
        $depId = ([string]$depItem).Trim()
        if (-not $depId) { continue }
        if ($dependencySeen.Contains($depId)) { continue }
        $dependencySeen[$depId] = $true
        $dependencyIds += $depId
    }

    $fileList = @()
    $notes = @()
    $sourceKind = ''
    $sourceRepo = ''
    $sourceTag = ''
    $version = ''
    if ($Resolve) {
        $fileList = @($Resolve.Files)
        $notes = @($Resolve.Notes)
        $sourceKind = [string]$Resolve.Kind
        $sourceRepo = [string]$Resolve.Repo
        $sourceTag = [string]$Resolve.Tag
        $version = [string]$Resolve.Version
    }

    $plan = [ordered]@{
        id              = $id
        name            = $displayName
        description     = (Get-EntryString -Entry $Entry -Key 'description')
        type            = $type
        version         = $version
        group           = $groupName
        dependencies    = @($dependencyIds)
        processes       = @(Get-EntryArray -Entry $Entry -Key 'processes')
        manifestOrigin  = $ManifestOrigin
        ok              = $false
        error           = ''
        notes           = $notes
        download        = [ordered]@{ kind = $sourceKind; repo = $sourceRepo; tag = $sourceTag; files = $fileList }
        install         = [ordered]@{ method = '' }
        postInstallCopy = @()
        env             = [ordered]@{}
        addToPath       = @()
        shortcuts       = [ordered]@{ desktop = $false; startMenu = $false }
        postInstall     = @()
        detect          = [ordered]@{ method = 'none' }
        uninstall       = [ordered]@{ method = '' }
    }

    if (-not $id) {
        $plan['error'] = '软件源条目缺少 id'
        return @{ Ok = $false; Error = $plan['error']; Plan = $plan; Notes = $notes }
    }
    # id 会拼成 installRoot\<id> 与 pkgDir\<id>：必须在解析期就拒绝「不是单层目录名」的 id
    # （`..` / 绝对路径 / 非法字符），否则清单里的 id 能把安装、覆盖、递归删除引到安装目录之外。
    # 这里 fail-fast，而不是等安装时再靠路径护栏兜底 —— 那时目录可能已经被写过一半。
    if (-not (Test-WinstSafePathSegment -Name $id)) {
        $plan['error'] = ('软件源条目 id 不合法（必须是单层目录名，不能是 . / .. 或含非法字符）：{0}' -f $id)
        return @{ Ok = $false; Error = $plan['error']; Plan = $plan; Notes = $notes }
    }

    if (-not $Resolve -or -not $Resolve.Ok) {
        $message = '来源解析失败'
        if ($Resolve -and $Resolve.Error) { $message = [string]$Resolve.Error }
        $plan['error'] = $message
        return @{ Ok = $false; Error = $message; Plan = $plan; Notes = $notes }
    }

    if (@('portable', 'installer', 'file', 'download') -notcontains $type) {
        $plan['error'] = ('未知的条目类型: {0}' -f $type)
        return @{ Ok = $false; Error = $plan['error']; Plan = $plan; Notes = $notes }
    }
    if ($typeRaw -and $typeRaw -ne $type) {
        $notes += ('软件源里的类型「{0}」已更名为「{1}」，本次按新名称处理' -f $typeRaw, $type)
        $plan['notes'] = $notes
    }

    return @{ Ok = $true; Error = ''; Plan = $plan; Notes = $notes }
}
