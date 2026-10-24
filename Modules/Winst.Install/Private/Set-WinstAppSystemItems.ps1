#Requires -Version 5.1

function Set-WinstAppSystemItems {
    <#
    .SYNOPSIS
        落地 env / PATH / 快捷方式。
    .DESCRIPTION
        `-KeepExisting`：**已存在的项保持不动、只补缺失的**——同名环境变量（同作用域）已存在就跳过
        （不覆盖其它软件 / 用户设置），快捷方式文件已存在就跳过；PATH 项本来就是「已存在则跳过」。
        它现在只用于**首次安装**（更新方式为「只更新文件」时，已登记软件（更新 / 重装）整段跳过本函数；不带该开关时按软件源里的定义落地（值不同则覆盖、快捷方式重建）。
    .OUTPUTS
        @{ AppliedEnv; AppliedPath; AppliedShortcuts; Notes }
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
        $appliedEnv += [ordered]@{ name = $name; scope = $scope }
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
    $shortcutPaths = @(Get-WinstShortcutPaths -Plan $Plan)
    if ($shortcutPaths.Count -gt 0) {
        $main = Get-WinstMainProgram -Plan $Plan -InstallDir $InstallDir
        if (-not $main) {
            $notes += '软件源里要求创建快捷方式，但没有指定主程序，已跳过'
        } else {
            $linkTarget = $main
            if (-not [IO.Path]::IsPathRooted($linkTarget)) { $linkTarget = Join-Path $InstallDir $linkTarget }
            # 主程序是 .ps1 脚本：快捷方式不能直接指向脚本（双击 .lnk 只会把脚本当文档打开、不会执行），
            # 先在脚本旁边生成同名 .cmd 启动器（winst.ps1 → winst.cmd），快捷方式指向它
            if ($linkTarget -match '(?i)\.ps1$') {
                try {
                    $linkTarget = New-WinstScriptLauncher -ScriptPath $linkTarget
                } catch {
                    $notes += ('创建脚本启动器失败（{0}）：{1}' -f $linkTarget, $_.Exception.Message)
                    $linkTarget = ''
                }
            }
            if (-not $linkTarget) {
                # 启动器没建成就别建快捷方式：指向 .ps1 的 .lnk 双击 / 点开始菜单都打不开
                $notes += ('主程序是脚本且未能生成同名 .cmd 启动器，已跳过快捷方式: {0}' -f $main)
            } else {
                $displayName = Get-EntryString -Entry $Plan -Key 'name'
                if (-not $displayName) { $displayName = Get-EntryString -Entry $Plan -Key 'id' }
                foreach ($link in $shortcutPaths) {
                    if ($KeepExisting -and (Test-Path -LiteralPath $link -PathType Leaf)) {
                        # 已存在就保留（不重建、也不登记为 winst 创建项）
                        $notes += ('快捷方式已存在，已保留: {0}' -f $link)
                        continue
                    }
                    try {
                        New-WinstShortcutFile -LinkPath $link -TargetPath $linkTarget -WorkingDirectory (Split-Path -Parent $linkTarget) -Description $displayName
                        $appliedShortcuts += $link
                    } catch {
                        $notes += ('创建快捷方式失败（{0}）：{1}' -f $link, $_.Exception.Message)
                    }
                }
            }
        }
    }

    return @{ AppliedEnv = $appliedEnv; AppliedPath = $appliedPath; AppliedShortcuts = $appliedShortcuts; Notes = $notes; Scope = $scope }
}
