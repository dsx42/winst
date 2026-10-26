#Requires -Version 5.1

function Show-WinstUninstallPlan {
    <#
    .SYNOPSIS
        展示「将删除 / 回收什么」，供用户确认。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Targets
    )

    Write-Host ''
    Write-Host ('  将要移除「{0}」：' -f [string]$Targets['Id']) -ForegroundColor Cyan
    # 卸载前先把当前版本号说清楚（口径与「已装软件」列表一致：取安装记录，识别不出就说明原因、不猜）
    $versionText = [string]$Targets['Version']
    if (-not $versionText) { $versionText = '未知（安装记录里没有版本号）' }
    elseif ($versionText -ieq 'unknown') { $versionText = '未知（没能识别出版本号）' }
    Write-Host ('    当前版本: {0}' -f $versionText) -ForegroundColor Gray
    $oldText = Format-WinstOldVersionText -OldVersions @($Targets['OldVersions'])
    if ($oldText) {
        # 按名称规则卸载会命中同名的全部记录：新旧两版一起被卸掉，这里必须提前说清
        Write-Host ('    并存的旧版本: {0}（卸载会一并移除；只想清旧的请用「已装软件」详情的 o)）' -f $oldText) -ForegroundColor DarkYellow
    }
    Write-Host ('    卸载动作来源: {0}' -f (@($Targets['Sources']) -join ' + ')) -ForegroundColor DarkGray
    foreach ($note in @($Targets['Notes'])) {
        Write-Host ('    提示: {0}' -f $note) -ForegroundColor DarkYellow
    }

    # 依赖（条目的 dependencies）：卸载确认里也把「这个软件依赖谁」说清楚（与其它详情同一套数据与文案，
    # 放在各分支之前，所以 external / winst 自身这些分支同样看得到
    $dependencyLines = @(Get-WinstDependencyLines -Context $Context -Id ([string]$Targets['Id']) -Type ([string]$Targets['Type']))
    if ($dependencyLines.Count -gt 0) {
        Write-Host '    依赖:' -ForegroundColor Gray
        foreach ($one in $dependencyLines) {
            Write-Host ('      - {0}' -f [string]$one['Text']) -ForegroundColor ([string]$one['Color'])
        }
    }

    if ([bool]$Targets['IsSelf']) {
        Write-Host '    winst 自身：删除安装目录里的脚本副本与启动器 winst.cmd' -ForegroundColor Gray
        Write-Host '    数据目录（软件源设置、已下载的安装包）保留，可自行删除' -ForegroundColor DarkGray
    } elseif ([bool]$Targets['External'] -and [string]$Targets['Method'] -eq 'record-only') {
        Write-Host '    该软件不是 winst 安装的，软件源里也没有卸载定义：只移除安装记录，不删除程序本身，也不改动系统设置' -ForegroundColor Yellow
        return
    } elseif ([string]$Targets['Method'] -eq 'registry') {
        Write-Host '    运行该软件自带的卸载程序（按安装记录里的名称规则在系统安装记录里实时查找）' -ForegroundColor Gray
        if ([string]$Targets['UninstallArgs']) {
            Write-Host ('    卸载参数: {0}' -f [string]$Targets['UninstallArgs']) -ForegroundColor DarkGray
        }
    } elseif ([string]$Targets['Method'] -eq 'appx') {
        $nameRuleText = (@($Targets['NameRule'] | ForEach-Object { [string]$_ }) -join '、')
        Write-Host ('    移除系统里已安装的应用包（名称规则: {0}）' -f $nameRuleText) -ForegroundColor Gray
    } elseif ([string]$Targets['Method'] -eq 'clean-cache') {
        Write-Host '    删除已下载的软件包（这个软件只下载软件包、不安装到电脑）' -ForegroundColor Gray
    } elseif ([string]$Targets['InstallDir']) {
        Write-Host ('    删除安装目录: {0}' -f [string]$Targets['InstallDir']) -ForegroundColor Gray
    } else {
        Write-Host '    删除安装目录（安装记录里没有路径，将使用「软件安装位置\id」）' -ForegroundColor Gray
    }

    # 卸载命令：删目录 / 跑官方卸载器**之前**执行，确认页先把命令列出来
    foreach ($command in @($Targets['Commands'])) {
        $exeText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'exe') -InstallDir ([string]$Targets['InstallDir']) -InstallRoot $Context.InstallRoot))
        $argsText = [Environment]::ExpandEnvironmentVariables((Expand-PlanPlaceholders -Value (Get-EntryString -Entry $command -Key 'args') -InstallDir ([string]$Targets['InstallDir']) -InstallRoot $Context.InstallRoot))
        Write-Host (('    执行卸载命令: {0} {1}' -f $exeText, $argsText).TrimEnd()) -ForegroundColor Gray
    }

    $cleanup = @($Targets['CleanupItems'])
    if ($cleanup.Count -eq 0) {
        Write-Host '    没有需要回收的环境变量 / PATH 项 / 快捷方式' -ForegroundColor DarkGray
        return
    }
    foreach ($one in $cleanup) {
        Write-Host ('    移除 {0}: {1}' -f [string]$one['Kind'], [string]$one['Text']) -ForegroundColor Gray
    }
}
