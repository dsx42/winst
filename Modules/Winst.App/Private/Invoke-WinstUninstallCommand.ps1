#Requires -Version 5.1

function Invoke-WinstUninstallCommand {
    <#
    .SYNOPSIS
        CLI：winst uninstall <id> [<id>...] [--force] [--yes]。
    .DESCRIPTION
        仅下载类型的软件没有安装记录，报错并提示改用 `winst clean <id>`。
    .OUTPUTS
        [int] 退出码：0 成功（含全部跳过）/ 1 参数错误或状态错误 / 3 卸载失败
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $ids = @()
    $force = $false
    $kill = $false
    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)

    foreach ($token in @($Arguments)) {
        $text = [string]$token
        if ($text -eq '--force') { $force = $true }
        elseif ($text -eq '--kill') { $kill = $true }
        elseif (Try-Apply-WinstCommonCliFlag -Text $text -Yes ([ref]$yes)) { }
        elseif ($text.StartsWith('-')) {
            Write-Host ''
            Write-Host ('  未知参数: {0}' -f $text) -ForegroundColor Yellow
            Write-Host '  用法: winst uninstall <id> [<id>...] [--force] [--kill] [--yes]' -ForegroundColor Gray
            return 1
        } else {
            if ($ids -notcontains $text) { $ids += $text }
        }
    }

    if ($ids.Count -eq 0) {
        Write-Host ''
        Write-Host '  用法: winst uninstall <id> [<id>...] [--force] [--kill] [--yes]' -ForegroundColor Yellow
        Write-Host '  示例: winst uninstall 7-Zip' -ForegroundColor Gray
        Write-Host '  说明: --force = 找不到卸载程序时只移除安装记录（软件已手动卸载的情况）；也用于跳过失败的卸载命令。' -ForegroundColor Gray
        Write-Host '        --kill = 软件正在运行时自动结束进程再卸载（非交互下不加会报错并提示先关闭它）。' -ForegroundColor Gray
        Write-Host '        仅下载类型的软件不安装到电脑，请用 winst clean <id> 删除已下载的软件包。' -ForegroundColor Gray
        return 1
    }

    Write-Section 'uninstall'

    # 软件类型：
    # 只有遇到安装记录里没有的 id 时才去读软件源，避免白跑一次清单加载。
    $typeById = $null

    $okCount = 0
    $skipCount = 0
    $failCount = 0
    $paramFail = 0
    $previewCount = 0
    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)

    # 台账读一次：下面逐 id 只做 Get-WinstInstalledApp 查表，避免每个 id 重解析 state.json
    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State

    foreach ($id in $ids) {
        Write-Host ''
        Write-Host ('  —— {0} ——' -f $id) -ForegroundColor Cyan

        $ledger = Get-WinstInstalledApp -State $state -Id $id
        if (-not $ledger) {
            if ($null -eq $typeById) {
                $typeById = New-WinstOrdinalDictionary
                foreach ($row in @(Get-WinstSearchCatalog -Context $Context)) {
                    $rowId = [string]$row['Id']
                    if (-not $rowId -or $typeById.Contains($rowId)) { continue }
                    $firstSource = @($row['Sources'])
                    if ($firstSource.Count -eq 0) { continue }
                    $typeById[$rowId] = (Get-EntryString -Entry $firstSource[0]['Plan'] -Key 'type').Trim().ToLowerInvariant()
                }
            }
            if ($typeById.Contains($id) -and ([string]$typeById[$id] -eq 'download')) {
                Write-Host ('  「{0}」是「只下载软件包」类型的软件：不安装到电脑、没有安装记录，无法卸载；请用 winst clean {0} 删除已下载的软件包。' -f $id) -ForegroundColor Yellow
            } else {
                Write-Host ('  安装记录里没有「{0}」这个软件（未安装）。' -f $id) -ForegroundColor Yellow
            }
            $paramFail++
            continue
        }

        $one = Invoke-WinstUninstallApp -Context $Context -Id $id -Force:$force -Kill:$kill -Yes:$yes
        if ($one.Cancelled) { $skipCount++; continue }
        if (-not $one.Ok) {
            Write-Host ('  失败: {0}' -f $one.Error) -ForegroundColor Red
            $failCount++
            continue
        }
        if ($dryRun) {
            Write-Host ('  {0}' -f $one.Message) -ForegroundColor Gray
            $previewCount++
            continue
        }
        Write-Host ('  {0}' -f $one.Message) -ForegroundColor Green
        if ($one.NeedRestart) { Write-Host '  提示: 卸载程序提示需要重启电脑才能完成。' -ForegroundColor DarkYellow }
        foreach ($note in @($one.Notes)) { Write-Host ('  提示: {0}' -f $note) -ForegroundColor DarkYellow }
        $okCount++
    }

    Write-Host ''
    if ($dryRun) {
        Write-Host ('  汇总: 预览 {0} / 失败 {1}（预览模式未做任何修改）' -f $previewCount, $failCount) -ForegroundColor $(if ($failCount -gt 0) { 'Yellow' } else { 'Gray' })
        if ($failCount -gt 0) { return 3 }
        if ($paramFail -gt 0 -and $previewCount -eq 0) { return 1 }
        return 0
    }
    Write-Host ('  汇总: 已卸载 {0} / 跳过 {1} / 失败 {2}' -f $okCount, $skipCount, $failCount) -ForegroundColor $(if (($failCount + $paramFail) -gt 0) { 'Yellow' } else { 'Gray' })

    if ($failCount -gt 0) { return 3 }
    if ($paramFail -gt 0 -and $okCount -eq 0) { return 1 }
    return 0
}
