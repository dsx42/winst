#Requires -Version 5.1

function Resolve-WinstShortcutTarget {
    <#
    .SYNOPSIS
        按清单算出快捷方式应指向的目标程序与起始位置。

    .DESCRIPTION
        主程序是 .ps1 脚本时先确保旁边有同名 `.cmd` 启动器（`.`lnk` 双击 `.ps1` 只会当文档打开），
        快捷方式改指向启动器。清单没有 mainExe、或启动器建不出来时返回空 Target，调用方跳过即可。

    .OUTPUTS
        @{ Target; WorkingDirectory; DisplayName; TargetIsMain; Note }
    #>
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$InstallDir
    )

    $result = @{ Target = ''; WorkingDirectory = ''; DisplayName = ''; TargetIsMain = $true; Note = '' }

    $displayName = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $displayName) { $displayName = Get-EntryString -Entry $Plan -Key 'id' }
    $result.DisplayName = $displayName

    $main = Get-WinstMainProgram -Plan $Plan -InstallDir $InstallDir
    if (-not $main) {
        $result.Note = '软件源里要求创建快捷方式，但没有指定主程序，已跳过'
        return $result
    }

    $linkTarget = $main
    if (-not [IO.Path]::IsPathRooted($linkTarget)) { $linkTarget = Join-WinstPath $InstallDir $linkTarget }

    if ($linkTarget -match '(?i)\.ps1$') {
        try {
            $linkTarget = New-WinstScriptLauncher -ScriptPath $linkTarget
        } catch {
            $result.Note = ('创建脚本启动器失败（{0}）：{1}' -f $linkTarget, $_.Exception.Message)
            return $result
        }
    }
    if (-not $linkTarget) {
        # 启动器没建成就别建快捷方式：指向 .ps1 的 .lnk 双击 / 点开始菜单都打不开
        $result.Note = ('主程序是脚本且未能生成同名 .cmd 启动器，已跳过快捷方式: {0}' -f $main)
        return $result
    }

    $result.Target = $linkTarget
    $result.WorkingDirectory = Split-Path -Parent $linkTarget
    return $result
}
