#Requires -Version 5.1

function Invoke-WinstUpdateCustomLoop {
    <#
    .SYNOPSIS
        逐条「单独选更新方式与来源」：选择方式或来源时回车 / b，即按默认方式与来源更新。
    .OUTPUTS
        @{ Updated = <int>; Skipped = <int>; Failed = <int> }
    #>
    param([hashtable]$Context, [string[]]$Targets, $Items = $null)

    $result = @{ Updated = 0; Skipped = 0; Failed = 0 }

    if ($null -eq $Items) {
        $overview = Get-WinstInstalledOverview -Context $Context
        if (-not $overview.Ok) {
            Write-Host ''
            Write-Host ('  {0}' -f $overview.Error) -ForegroundColor Red
            return $result
        }
        $Items = @($overview.Items)
    }
    $itemById = New-WinstOrdinalDictionary
    foreach ($one in @($Items)) {
        $oneId = [string]$one['Id']
        if ($oneId -and -not $itemById.Contains($oneId)) { $itemById[$oneId] = $one }
    }

    foreach ($id in @($Targets)) {
        if ((Get-WinstState -Name WinstQuitRequested)) { return $result }
        $item = $null
        if ($itemById.Contains($id)) { $item = $itemById[$id] }
        if (-not $item) {
            Write-Host ('  {0}: 已跳过：安装记录里没有这个软件。' -f $id) -ForegroundColor DarkYellow
            $result.Failed++
            continue
        }

        $customResult = @{ Cancelled = $true; Ok = $false; Updated = 0; Skipped = 0; Failed = 0 }
        if ($item['Row']) {
            # 复用「已装软件 → c」的完整流程（选方式 → 选来源 → 同版本 / 低版本按强制处理 → 确认执行）
            $customResult = Invoke-WinstUpdateCustom -Context $Context -Item $item
        } else {
            Write-Host ('  {0}: 软件源里没有这个软件，改成按默认来源更新。' -f [string]$item['DisplayName']) -ForegroundColor DarkYellow
        }

        if ((Get-WinstState -Name WinstQuitRequested)) { return $result }
        if ($customResult.Cancelled) {
            Write-Host ('  将按默认方式更新这 1 个软件（方式: {0}；来源: 优先安装时用的软件源）。' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor Gray
            $updated = Invoke-WinstUpdateTargets -Context $Context -Ids @($id) -AutoPickSource -Yes
            $customResult = ConvertFrom-WinstUpdateTargetsResult -Result $updated
        }

        $result.Updated += [int]$customResult.Updated
        $result.Skipped += [int]$customResult.Skipped
        $result.Failed += [int]$customResult.Failed
    }

    return $result
}
