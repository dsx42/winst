#Requires -Version 5.1

function Invoke-WinstApplySystemItems {
    <#
    .SYNOPSIS
        ③ 复制 / 改名 ④ 环境变量 / PATH / 快捷方式 ⑤ 安装后命令（按「更新方式」决定是否落地系统项）。
    .DESCRIPTION
        安装版软件没有可确定的安装目录时（安装命令未指定路径、系统安装记录里也没有）这几步无目录可用：
        installer 条目本就不写系统项（见清单构建），直接跳过即可，不把空目录传下去。
        「只更新文件」时**环境变量 / PATH 整段跳过**——保持原样，台账里原有的 applied* 登记也不动——
        多个同族软件共存（如 jdk8 / jdk21 / jdk25 都声明 JAVA_HOME）时，更新其中一个不会碰共享变量；
        快捷方式只修正已存在的（见下），postInstall 命令照常执行。两种来源都按这个口径：
        CLI `--files-only` 一律跳过；「设置 → 更新方式」= 只更新文件（默认）时，只有**本机已有登记**
        （本次是更新 / 重装）才跳过。
        首次安装（台账里没有这条软件）例外：「只更新文件」是「更新」的口径，用它去掐掉新装软件的环境变量 /
        快捷方式等于新装的软件没配好环境，因此首次安装仍按 keep 语义补齐缺失（已存在的保持不动）。

        **快捷方式一律校验，两种模式都不放过**：安装位置换过、旧版本残留、被手工改过都会留下指向
        不存在程序的 .lnk，双击打不开。因此：
        - 完整安装：缺的建、指向不对的修；
        - 只更新文件：**只修已存在的**（用户删掉的不补建，见 Set-WinstAppShortcuts -ExistingOnly）。
    .OUTPUTS
        @{ Items; Skipped; Error }
    #>
    param([hashtable]$Context, $Plan, [string]$InstallDir, [switch]$FilesOnly, [switch]$ForceSystemItems,
        $Ledger, [switch]$Quiet)

    $systemItems = @{ AppliedEnv = @(); AppliedPath = @(); AppliedShortcuts = @(); RepairedShortcuts = @(); Notes = @() }
    if (-not $InstallDir) { return @{ Items = $systemItems; Skipped = $false; Error = '' } }

    $copy = Invoke-WinstPostInstallCopy -Plan $Plan -InstallDir $InstallDir
    if (-not $copy.Ok) { return @{ Items = $systemItems; Skipped = $false; Error = [string]$copy.Error } }

    # 完整性优先级：-ForceSystemItems（完整更新）> -FilesOnly（彻底只更新文件）> 「设置 → 更新方式」。
    $keepExisting = $true
    if ($ForceSystemItems) {
        $keepExisting = $false
    } elseif (-not $FilesOnly) {
        $keepExisting = [bool](Get-ConfigValue -Config $Context.Config -Key 'updateFilesOnly' -Default $true)
    }
    $systemItemsSkipped = [bool]$FilesOnly -or ($keepExisting -and [bool]$Ledger)

    if ($systemItemsSkipped) {
        if (-not $Quiet) {
            if ($FilesOnly) {
                Write-Host '    仅更新文件：环境变量 / PATH 保持原样；只校验并修正已存在的快捷方式' -ForegroundColor DarkYellow
            } else {
                Write-Host '    只更新文件：环境变量 / PATH 保持原样；只校验并修正已存在的快捷方式' -ForegroundColor DarkGray
            }
        }
        # 环境变量 / PATH 不动，但已有快捷方式必须校验：位置换过以后旧 .lnk 指向空目录，双击打不开
        $shortcuts = Set-WinstAppShortcuts -Plan $Plan -InstallDir $InstallDir -ExistingOnly
        $systemItems.AppliedShortcuts = @($shortcuts.Applied)
        $systemItems.RepairedShortcuts = @($shortcuts.Repaired)
        if (-not $Quiet) {
            foreach ($note in @($shortcuts.Notes)) {
                if ($note -like '*已保留*') { continue }
                Write-Host ('    提示: {0}' -f $note) -ForegroundColor DarkYellow
            }
        }
    } else {
        if ($keepExisting -and -not $Quiet) {
            Write-Host '    首次安装：补齐缺失的环境变量 / 快捷方式（已存在的保持不动）' -ForegroundColor DarkGray
        }
        $systemItems = Set-WinstAppSystemItems -Context $Context -Plan $Plan -InstallDir $InstallDir -KeepExisting:$keepExisting
        foreach ($note in @($systemItems.Notes)) { Write-Host ('    提示: {0}' -f $note) -ForegroundColor DarkYellow }
    }

    $post = Invoke-WinstPostInstallCommands -Context $Context -Plan $Plan -InstallDir $InstallDir
    if (-not $post.Ok) { return @{ Items = $systemItems; Skipped = $systemItemsSkipped; Error = [string]$post.Error } }

    return @{ Items = $systemItems; Skipped = $systemItemsSkipped; Error = '' }
}
