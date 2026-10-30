#Requires -Version 5.1

function Invoke-WinstRunUninstaller {
    <#
    .SYNOPSIS
        实时回读系统安装记录里的卸载命令并执行。
    .DESCRIPTION
        名称规则可能命中**多条**记录：如 .NET 运行时同时有 burn 引导包（exe 卸载器，卸载时会连带移除
        内层 MSI 的注册）与内层 MSI（MsiExec /X）两条——按「exe 卸载器在前、MsiExec 在后」逐条执行，
        每条执行前重新回读注册表，已被上一次卸载连带移除的记录直接跳过；MsiExec 返回 1605（产品不存在）
        也视为已卸载。只处理其中一条时，另一条会留在系统里（设置 → 应用仍能看到）。
    .OUTPUTS
        @{ Ok; Missing; NeedRestart; Error; Command; ExitCode }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [switch]$Quiet
    )

    $result = @{ Ok = $false; Missing = $false; NeedRestart = $false; Error = ''; Command = ''; ExitCode = 0 }

    $ruleText = Get-WinstRegistryNameRuleForPlan -Plan $Plan
    if (-not $ruleText) {
        $result.Missing = $true
        $result.Error = '系统安装记录里没有找到这个软件的卸载程序'
        return $result
    }
    $rule = New-MatchRule -Rule $ruleText -Kind '软件名称'
    if (-not $rule.Ok) {
        $result.Missing = $true
        $result.Error = '系统安装记录里没有找到这个软件的卸载程序'
        return $result
    }

    $uninstallBlock = Get-EntryValue -Entry $Plan -Key 'uninstall' -Default $null
    $extraArgs = Get-EntryString -Entry $uninstallBlock -Key 'uninstallArgs'

    # 命中的全部记录：exe 卸载器（burn 引导包等）在前——它的卸载会连带移除内层 MSI；MsiExec /X 在后；同组按显示名
    $hits = @()
    foreach ($candidate in @(Get-WinstInstalledRegistryEntries)) {
        if (-not (Test-CompiledMatchRule -Rule $rule -Text ([string]$candidate['DisplayName']))) { continue }
        $commandLine = [string]$candidate['UninstallString']
        if (-not $commandLine) { continue }
        $isMsiExec = $commandLine.Trim().StartsWith('msiexec', [StringComparison]::OrdinalIgnoreCase)
        $hits += [ordered]@{ Entry = $candidate; CommandLine = $commandLine; IsMsiExec = $isMsiExec }
    }
    if ($hits.Count -eq 0) {
        $result.Missing = $true
        $result.Error = '系统安装记录里没有找到这个软件的卸载程序'
        return $result
    }
    $sorted = @($hits | Sort-Object -Property @{ Expression = { [bool]$_['IsMsiExec'] } }, @{ Expression = { [string]$_['Entry']['DisplayName'] } })

    $ran = 0
    $orphanKeys = New-Object 'System.Collections.Generic.List[object]'
    foreach ($hit in $sorted) {
        # 每条执行前重新回读：上一次卸载可能把这条记录连带移除了（如引导包卸载会移除内层 MSI 的注册）
        $keyPath = [string]$hit['Entry']['KeyPath']
        if ($keyPath -and -not (Test-Path -LiteralPath $keyPath)) { continue }
        $commandLine = [string]$hit['CommandLine']

        # 卸载器文件可能已被清理（如 burn 引导包的 Package Cache 缓存被磁盘清理删掉，注册表记录成了孤儿）：
        # 跳过这条记录、继续尝试下一条（如内层 MSI 的 MsiExec /X，其缓存在 C:\Windows\Installer 不受影响）；
        # 全部不可用才报错。有卸载成功时，失效的孤儿注册键一并清掉（不清理会一直留在「设置 → 应用」里）
        $command = Resolve-WinstUninstallerCommand -CommandLine $commandLine -ExtraArgs $extraArgs
        if (-not $command.Ok) {
            if ([bool]$command.Missing) {
                if ($keyPath) { $orphanKeys.Add([ordered]@{ KeyPath = $keyPath; DisplayName = [string]$hit['Entry']['DisplayName'] }) }
                if (-not $Quiet) { Write-Host ('    卸载器文件不存在，跳过: {0}' -f [string]$command.Exe) -ForegroundColor DarkYellow }
                continue
            }
            $result.Error = [string]$command.Error
            return $result
        }
        $exeText = [string]$command.Exe
        $result.Command = [string]$command.Command

        if (-not $Quiet) { Write-Host ('    正在运行卸载程序: {0}' -f $result.Command) -ForegroundColor Gray }
        try {
            $params = @{ FilePath = $exeText; Wait = $true; PassThru = $true }
            if ([string]$command.Args) { $params['ArgumentList'] = [string]$command.Args }
            $process = Start-Process @params
            if ($null -eq $process -or $null -eq $process.ExitCode) {
                # [int]$null 会得到 0（= 成功），随后台账被移除而程序还在
                $result.Error = '读不到卸载程序退出码，未确认卸载成功（如已手动卸载，可加 --force 只移除安装记录）'
                return $result
            }
            $result.ExitCode = [int]$process.ExitCode
        } catch {
            $result.Error = ('运行卸载程序失败：{0}' -f $_.Exception.Message)
            return $result
        }
        $ran++

        if ($result.ExitCode -eq 3010) {
            $result.NeedRestart = $true
            continue
        }
        if ($result.ExitCode -eq 1605) {
            # 1605 = 产品未安装：已被上一条卸载连带移除 → 视为已卸载
            continue
        }
        if ($result.ExitCode -ne 0) {
            $result.Error = ('卸载程序返回失败（退出码 {0}）' -f $result.ExitCode)
            return $result
        }
    }

    if ($ran -eq 0) {
        # 全部记录都被跳过（卸载器文件缺失 / 记录已失效）→ 没有任何卸载动作可执行
        $result.Ok = $false
        $result.Error = '没有可用的卸载器：匹配到的卸载程序文件都缺失或记录已失效；如已手动卸载，可加 --force 只移除安装记录'
        return $result
    }

    # 卸载成功后收尾：清理「卸载器文件缺失」的孤儿注册键（它们的卸载器已不在，留着的唯一作用是
    # 让「设置 → 应用」里一直显示这个软件）
    foreach ($orphan in $orphanKeys.ToArray()) {
        $orphanPath = [string]$orphan['KeyPath']
        # 只允许删「卸载记录」分支下的键：KeyPath 虽然来自注册表枚举，但脏数据 / 被改过的值
        # 不能拿去递归删除任意注册表键。`[^\\]+` 会匹配 `..`（解析出来是 CurrentVersion），
        # 因此额外排除带 . / .. 段与尾点的写法
        if ($orphanPath -match '\\\.\.?(\\|$)' -or $orphanPath -match '\\[^\\]*\.$' -or
            $orphanPath -notmatch '(?i)\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\[^\\]+$') {
            if (-not $Quiet) { Write-Host ('    提示: 跳过不在卸载记录分支下的注册表键: {0}' -f $orphanPath) -ForegroundColor DarkYellow }
            continue
        }
        try {
            Remove-Item -LiteralPath $orphanPath -Recurse -Force -ErrorAction Stop
            if (-not $Quiet) { Write-Host ('    已清理失效的安装记录（卸载器文件缺失）: {0}' -f [string]$orphan['DisplayName']) -ForegroundColor Gray }
        } catch {
            if (-not $Quiet) { Write-Host ('    提示: 失效的安装记录未能清理（{0}）: {1}' -f $_.Exception.Message, $orphanPath) -ForegroundColor DarkYellow }
        }
    }

    $result.Ok = $true
    return $result
}
