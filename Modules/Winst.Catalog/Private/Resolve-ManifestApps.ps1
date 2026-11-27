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

        try {
            $plan = New-WinstCatalogAppPlan -ManifestOrigin $ManifestOrigin -Entry $entry -Context $Context
        } catch {
            $reason = $_.Exception.Message
            $plan = New-WinstPlanBase -ManifestOrigin $ManifestOrigin -Entry @{ id = $id; name = $displayName
                type = (Get-EntryString -Entry $entry -Key 'type'); description = (Get-EntryString -Entry $entry -Key 'description') }
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
        $versionSlotText = ('版本 {0}' -f $versionText)
        if ([string]$plan['remoteFresh'] -ieq 'changed') {
            $versionSlotText = '远端文件已变化，版本待确认'
            if ($lineColor -eq 'DarkGray') { $lineColor = 'Yellow' }
        } elseif ([string]$plan['remoteFresh'] -ieq 'unknown') {
            $versionSlotText = '远端文件变化情况未知，版本待确认'
            if ($lineColor -eq 'DarkGray') { $lineColor = 'DarkYellow' }
        }
        Write-Host ('    [{0}/{1}] {2}  {3}  {4}' -f $index, $Entries.Count, $displayName, $versionSlotText, $mark) -NoNewline -ForegroundColor $lineColor
        Write-Host ''

        $apps.Add($plan)
    }

    return @{ Apps = @($apps.ToArray()); Succeeded = $succeeded; Failed = $failed }
}
