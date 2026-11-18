#Requires -Version 5.1

function Resolve-ManifestApps {
    <#
    .SYNOPSIS
        对清单内条目做解析，生成解析锁条目数组（失败隔离，单条失败不影响其余）。
    .OUTPUTS
        @{ Apps = <计划数组>; Succeeded = <int>; Failed = <int> }
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$ManifestOrigin,
        [object[]]$Entries
    )

    $apps = New-Object 'System.Collections.Generic.List[object]'
    $succeeded = 0
    $failed = 0
    $index = 0
    # 按需刷新根据逐条目的 UTC 时间判断版本信息是否过期。
    $resolvedNow = [DateTime]::UtcNow.ToString('o')

    foreach ($entry in $Entries) {
        $id = Get-EntryString -Entry $entry -Key 'id'

        $index++
        $displayName = Get-EntryString -Entry $entry -Key 'name'
        if (-not $displayName) { $displayName = $id }

        $plan = $null
        try {
            $plan = New-WinstCatalogAppPlan -ManifestOrigin $ManifestOrigin -Entry $entry -PkgDir $Context.PkgDir -Context $Context
        } catch {
            $reason = $_.Exception.Message
            $plan = (New-WinstPlanBase -ManifestOrigin $ManifestOrigin -Entry @{ id = $id; name = $displayName
                type = (Get-EntryString -Entry $entry -Key 'type'); description = (Get-EntryString -Entry $entry -Key 'description') }).Plan
            $plan['error'] = $reason
        }
        $plan['resolvedAt'] = $resolvedNow

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
        Write-Host ('    [{0}/{1}] {2}  {3}  {4}' -f $index, $Entries.Count, $displayName, $versionSlotText, $mark) -NoNewline -ForegroundColor $lineColor
        Write-Host ''

        $apps.Add($plan)
    }

    return @{ Apps = @($apps.ToArray()); Succeeded = $succeeded; Failed = $failed }
}
