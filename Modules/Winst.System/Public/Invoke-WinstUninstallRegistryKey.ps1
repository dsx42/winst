#Requires -Version 5.1

function Invoke-WinstUninstallRegistryKey {
    <#
    .SYNOPSIS
        按**卸载键路径**运行系统安装记录里的那条卸载程序（用于只移除某个旧版本）。
    .DESCRIPTION
        与 Invoke-WinstRunUninstaller 的区别：那个按名称规则命中全部记录（会把所有版本一起卸掉），
        这里只针对一条具体记录——升级后旧版本还留在系统里时，用户可能只想清掉旧的。

        执行前重新回读该键（记录可能已被其它卸载动作连带移除），按 Resolve-WinstUninstallerCommand
        解析命令、校验路径与参数后运行。MsiExec 返回 1605（产品不存在）视为已移除。
    .OUTPUTS
        @{ Ok; Missing; NeedRestart; Error; Command; ExitCode }
    #>
    param([string]$KeyPath, [string]$ExtraArgs = '', [switch]$Quiet)

    $result = @{ Ok = $false; Missing = $false; NeedRestart = $false; Error = ''; Command = ''; ExitCode = 0 }

    if (-not $KeyPath) { $result.Missing = $true; $result.Error = '缺少卸载记录'; return $result }
    # 只允许卸载记录分支下的键：KeyPath 虽然来自注册表枚举，但脏数据 / 被改过的值不能拿去执行
    if ($KeyPath -notmatch '(?i)\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\[^\\]+$') {
        $result.Error = ('不是系统安装记录里的键，已拒绝执行: {0}' -f $KeyPath)
        return $result
    }

    $props = $null
    try { $props = Get-ItemProperty -LiteralPath $KeyPath -ErrorAction SilentlyContinue } catch { $props = $null }
    if ($null -eq $props) { $result.Missing = $true; $result.Error = '这条安装记录已经不存在'; return $result }

    $commandLine = ''
    $prop = $props.PSObject.Properties['UninstallString']
    if ($prop -and $null -ne $prop.Value) { $commandLine = [string]$prop.Value }
    if (-not $commandLine) { $result.Missing = $true; $result.Error = '这条安装记录里没有卸载命令'; return $result }

    $command = Resolve-WinstUninstallerCommand -CommandLine $commandLine -ExtraArgs $ExtraArgs
    if (-not $command.Ok) {
        $result.Missing = [bool]$command.Missing
        $result.Error = [string]$command.Error
        return $result
    }
    $result.Command = [string]$command.Command

    if (-not $Quiet) { Write-Host ('    正在运行卸载程序: {0}' -f $result.Command) -ForegroundColor Gray }
    try {
        $params = @{ FilePath = [string]$command.Exe; Wait = $true; PassThru = $true }
        if ([string]$command.Args) { $params['ArgumentList'] = [string]$command.Args }
        $process = Start-Process @params
        $result.ExitCode = [int]$process.ExitCode
    } catch {
        $result.Error = ('运行卸载程序失败：{0}' -f $_.Exception.Message)
        return $result
    }

    if ($result.ExitCode -eq 3010) {
        $result.Ok = $true
        $result.NeedRestart = $true
        return $result
    }
    if ($result.ExitCode -eq 1605 -or $result.ExitCode -eq 0) {
        # 1605 = 产品未安装（已被上一条卸载连带移除）→ 视为已移除
        $result.Ok = $true
        return $result
    }
    $result.Error = ('卸载程序返回失败（退出码 {0}）' -f $result.ExitCode)
    return $result
}
