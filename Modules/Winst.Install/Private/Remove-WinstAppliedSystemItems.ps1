#Requires -Version 5.1

function Remove-WinstAppliedSystemItems {
    <#
    .SYNOPSIS
        ② 回收 winst 写入的系统项：快捷方式 / 环境变量（含「仍被其它软件使用时恢复」）/ PATH 项。
    #>
    param([hashtable]$Context, $State, [string]$Id, $Targets, [hashtable]$RunState, [switch]$Quiet)

    foreach ($item in @($Targets['Shortcuts'])) {
        $link = [string]$item
        if (-not $link) { continue }
        $r = Remove-WinstShortcutFile -LinkPath $link
        if ($r.Ok) {
            if ($r.Removed -and -not $Quiet) { Write-Host ('    已删除快捷方式: {0}' -f $link) -ForegroundColor Gray }
        } else {
            $RunState.Notes += ('删除快捷方式失败（{0}）：{1}' -f $link, $r.Error)
        }
    }

    foreach ($item in @($Targets['Env'])) {
        $name = Get-EntryString -Entry $item -Key 'name'
        if (-not $name) { continue }
        $scope = Get-EntryString -Entry $item -Key 'scope'
        if ($scope -ne 'Machine') { $scope = 'User' }

        # 同一作用域还有别的软件声明同名变量 → 恢复为其中最近安装的那个需要的值
        $restore = Get-WinstEnvRestoreValue -Context $Context -State $State -Name $name -Scope $scope -ExceptId $Id
        if ($restore.Found) {
            if ($restore.Error) {
                $RunState.Notes += ('环境变量 {0} 仍被其它已装软件使用，本次保留、未删除（{1}）' -f $name, $restore.Error)
                continue
            }
            if ($restore.FromId -ceq $Id) { continue }
            try {
                Set-WinstEnvironmentVariableEx -Name $name -Value $restore.Value -Scope $scope
                if (-not $Quiet) { Write-Host ('    环境变量 {0} 已恢复为「{1}」需要的值' -f $name, $restore.FromId) -ForegroundColor Gray }
            } catch {
                $RunState.Notes += ('恢复环境变量 {0} 失败：{1}' -f $name, $_.Exception.Message)
            }
            continue
        }

        try {
            if ([bool](Get-EntryBool -Entry $item -Key 'existed')) {
                # 安装前就有这个变量（值被本软件覆盖过）：还原原值，不删用户的设置
                $previous = Get-EntryString -Entry $item -Key 'previous'
                Set-WinstEnvironmentVariableEx -Name $name -Value $previous -Scope $scope
                if (-not $Quiet) { Write-Host ('    环境变量 {0} 已还原为安装前的值' -f $name) -ForegroundColor Gray }
            } else {
                $removedVariable = Remove-WinstEnvironmentVariableEx -Name $name -Scope $scope
                if ($removedVariable -and -not $Quiet) { Write-Host ('    已移除环境变量: {0}（{1}）' -f $name, $scope) -ForegroundColor Gray }
            }
        } catch {
            $RunState.Notes += ('回收环境变量 {0} 失败：{1}' -f $name, $_.Exception.Message)
        }
    }

    foreach ($item in @($Targets['PathItems'])) {
        $path = Get-EntryString -Entry $item -Key 'path'
        if (-not $path) { continue }
        $scope = Get-EntryString -Entry $item -Key 'scope'
        if ($scope -ne 'Machine') { $scope = 'User' }

        if (Test-WinstPathEntryClaimed -Context $Context -State $State -Path $path -Scope $scope -ExceptId $Id) {
            if (-not $Quiet) { Write-Host ('    PATH 项仍被其它已装软件使用，已保留: {0}' -f $path) -ForegroundColor Gray }
            continue
        }
        $r = Remove-WinstPathEntry -PathValue $path -Scope $scope
        if ($r.Ok) {
            if ($r.Removed -gt 0 -and -not $Quiet) { Write-Host ('    已移除 PATH 项: {0}（{1}）' -f $path, $scope) -ForegroundColor Gray }
        } else {
            $RunState.Notes += ('移除 PATH 项 {0} 失败：{1}' -f $path, $r.Error)
        }
    }
}
