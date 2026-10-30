#Requires -Version 5.1

function Resolve-ManifestApps {
    <#
    .SYNOPSIS
        对清单内条目做解析，生成解析锁条目数组（失败隔离，单条失败不影响其余）。
    .DESCRIPTION
        -OnlyIds 只解析命中的条目：未命中的条目跳过，由
        Update-ManifestSource 合并 sidecar 既有缓存。
    .OUTPUTS
        @{ Apps = <计划数组>; Succeeded = <int>; Failed = <int>; Skipped = <int> }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$ManifestOrigin,
        $Entries,
        [string[]]$OnlyIds = @()
    )

    $entryList = @($Entries)
    $onlySet = $null
    if (@($OnlyIds).Count -gt 0) { $onlySet = Get-WinstIdFilterSet -Ids $OnlyIds }

    # 进度分母用「本次要解析的条目数」：按需解析时不该显示整份清单的总数
    $targetTotal = $entryList.Count
    if ($onlySet) {
        $targetTotal = 0
        foreach ($one in $entryList) {
            $oneId = Get-EntryString -Entry $one -Key 'id'
            if ($oneId -and $onlySet.ContainsKey($oneId)) { $targetTotal++ }
        }
    }

    $apps = New-Object 'System.Collections.Generic.List[object]'
    $succeeded = 0
    $failed = 0
    $skipped = 0
    $index = 0
    # per-app 解析时间戳（ISO 's'，与 sidecar resolvedAt 同口径）：按需刷新据此判断单条版本信息的新旧
    $resolvedNow = (Get-Date).ToString('s')

    foreach ($entry in $entryList) {
        $id = Get-EntryString -Entry $entry -Key 'id'
        if ($onlySet) {
            if (-not $id -or -not $onlySet.ContainsKey($id)) { $skipped++; continue }
        }
        $index++
        $displayName = Get-EntryString -Entry $entry -Key 'name'
        if (-not $displayName) { $displayName = $id }

        $plan = $null
        try {
            $resolve = Resolve-AppSource -Context $Context -Entry $entry
            $plan = New-ResolvedAppPlan -ManifestOrigin $ManifestOrigin -Entry $entry -Resolve $resolve -PkgDir $Context.PkgDir -Context $Context
        } catch {
            $plan = [ordered]@{
                id             = $id
                name           = $displayName
                description    = (Get-EntryString -Entry $entry -Key 'description')
                type           = (Get-EntryString -Entry $entry -Key 'type')
                version        = ''
                manifestOrigin = $ManifestOrigin
                ok             = $false
                error          = $_.Exception.Message
                notes          = @()
                download       = [ordered]@{ kind = ''; repo = ''; tag = ''; files = @() }
                install        = [ordered]@{ method = '' }
                postInstallCopy = @()
                env            = [ordered]@{}
                addToPath      = @()
                shortcuts      = [ordered]@{ desktop = $false; startMenu = $false }
                postInstall    = @()
                detect         = [ordered]@{ method = 'none' }
                uninstall      = [ordered]@{ method = '' }
                resolvedAt     = $resolvedNow
            }
        }
        try { $plan['resolvedAt'] = $resolvedNow } catch { }

        if ($plan['ok']) { $succeeded++ } else { $failed++ }

        # 逐条结果：解析有误整行标红；版本未知但有可用版本信息的标黄（方便一眼区分「读不出来」与「读出来但没版本号」）
        $mark = '可用'
        if (-not $plan['ok']) { $mark = '有误' }
        $versionText = [string]$plan['version']
        $versionUnknown = $false
        if (-not $versionText -or $versionText -ieq 'unknown') { $versionText = '未知'; $versionUnknown = $true }
        $lineColor = 'DarkGray'
        if (-not $plan['ok']) { $lineColor = 'Red' }
        elseif ($versionUnknown) { $lineColor = 'DarkYellow' }
        # 无法获取最新版本号的条目：解析时已用 HEAD 比对过
        # 远端与缓存记账（结论在解析锁 remoteFresh 里）——远端有新包时版本槽直接写「新版本」（整行标黄，
        # 不单列行尾提示）；远端无新包时版本槽就是缓存里那份包的版本（解析时从包内文件信息 / 缓存索引取得）
        $versionSlotText = ('版本 {0}' -f $versionText)
        if ([string]$plan['remoteFresh'] -ieq 'changed') {
            $versionSlotText = '新版本'
            if ($lineColor -eq 'DarkGray') { $lineColor = 'Yellow' }
        }
        Write-Host ('    [{0}/{1}] {2}  {3}  {4}' -f $index, $targetTotal, $displayName, $versionSlotText, $mark) -NoNewline -ForegroundColor $lineColor
        Write-Host ''

        $apps.Add($plan)
    }

    return @{ Apps = @($apps.ToArray()); Succeeded = $succeeded; Failed = $failed; Skipped = $skipped }
}
