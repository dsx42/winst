#Requires -Version 5.1

function Set-WinstAppSystemItems {
    <#
    .SYNOPSIS
        落地 env / PATH / 快捷方式。
    .DESCRIPTION
        `-KeepExisting`：**已存在的环境变量保持不动、只补缺失的**——同名环境变量（同作用域）已存在就跳过
        （不覆盖其它软件 / 用户设置）。
        它现在只用于**首次安装**（更新方式为「只更新文件」时，已登记软件（更新 / 重装）整段跳过本函数；不带该开关时按软件源里的定义落地（值不同则覆盖）。

        快捷方式口径（两种模式一致）：
        - 不存在 → 按清单定义创建；
        - 已存在且目标 / 起始位置正确 → 保留，不重写文件；
        - 已存在但指向不对 → **覆盖修正**。安装位置换过、旧版本残留、被手工改过都会留下指向
          不存在程序的快捷方式，留着就是「双击打不开」，因此必须修。

        「仅更新文件」模式不做本函数（环境变量一律不动），改由 Set-WinstAppShortcuts -ExistingOnly
        修正已经存在但指向不对的快捷方式。
    .OUTPUTS
        @{ AppliedEnv; AppliedPath; AppliedShortcuts; RepairedShortcuts; Notes; Scope }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [switch]$KeepExisting
    )

    $appliedEnv = @()
    $appliedPath = @()
    $appliedShortcuts = @()
    $repairedShortcuts = @()
    $notes = @()

    $scope = Get-WinstInstallScope -InstallDir $InstallDir

    # env
    $envMap = Get-EntryValue -Entry $Plan -Key 'env' -Default $null
    foreach ($pair in @(Get-EntryKeyValuePairs -Entry $envMap)) {
        $name = [string]$pair['Key']
        if (-not $name) { continue }
        $value = Expand-PlanPlaceholders -Value ([string]$pair['Value']) -InstallDir $InstallDir -InstallRoot $Context.InstallRoot
        # 当前值用 WMI 读原值（不展开）——与清单写法可以直接逐字比较
        $current = Get-WinstEnvironmentValue -Name $name -Scope $scope
        if ($null -ne $current) {
            if ($KeepExisting) {
                # 已存在就保留原有设置（不覆盖、也不登记为 winst 写入项）
                $notes += ('环境变量 {0} 已存在，已保留现有设置' -f $name)
                continue
            }
            if ($current -ceq $value) { continue }
        }
        Set-WinstEnvironmentVariableEx -Name $name -Value $value -Scope $scope
        # 记下覆盖前的原值：卸载时据此还原，否则「本来就有、被本软件覆盖」的变量会被直接删掉
        $appliedEnv += [ordered]@{
            name     = $name
            scope    = $scope
            existed  = ($null -ne $current)
            previous = [string]$current
        }
    }

    # PATH：**放在环境变量之后写入**
    # —— PATH 项常写成 %MAVEN_HOME%\bin / %JAVA_HOME%\bin 这类引用，先把被引用的变量写好再写 PATH，
    #    读取方（新开的终端 / 本次会话）解析到时才有值可展开，不会出现「变量稍后才写、PATH 先成死文本」。
    #    %VAR% 原样写入、不展开；读写一律走 WMI Win32_Environment。
    $pathItems = @(Get-EntryArray -Entry $Plan -Key 'addToPath')
    if ($pathItems.Count -gt 0) {
        $currentPath = Get-WinstEnvironmentValue -Name 'Path' -Scope $scope
        if ($null -eq $currentPath) { $currentPath = '' }
        $segments = @(Get-WinstPathSegments -Value $currentPath)
        $changed = $false
        foreach ($item in $pathItems) {
            $text = [string]$item
            if (-not $text) { continue }
            if ($text -ieq 'true' -or $text -ieq '{installDir}') { $text = $InstallDir }
            else { $text = Expand-PlanPlaceholders -Value $text -InstallDir $InstallDir -InstallRoot $Context.InstallRoot }
            if (-not $text) { continue }
            if (Test-WinstPathSegmentExists -Segments $segments -Value $text) { continue }
            $segments += $text
            $appliedPath += [ordered]@{ path = $text; scope = $scope }
            $changed = $true
        }
        if ($changed) {
            Set-WinstEnvironmentVariableEx -Name 'Path' -Value ($segments -join ';') -Scope $scope
        }
    }

    # 快捷方式（始终用户级；路径规则见 Get-WinstShortcutPaths）
    $shortcuts = Set-WinstAppShortcuts -Plan $Plan -InstallDir $InstallDir
    $appliedShortcuts = @($shortcuts.Applied)
    $repairedShortcuts = @($shortcuts.Repaired)
    foreach ($note in @($shortcuts.Notes)) { $notes += $note }

    return @{ AppliedEnv = $appliedEnv; AppliedPath = $appliedPath; AppliedShortcuts = $appliedShortcuts
              RepairedShortcuts = $repairedShortcuts; Notes = $notes; Scope = $scope }
}
