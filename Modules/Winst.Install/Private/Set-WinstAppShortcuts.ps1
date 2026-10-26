#Requires -Version 5.1

function Set-WinstAppShortcuts {
    <#
    .SYNOPSIS
        按清单落地快捷方式：不存在就创建，存在但指向不对就覆盖修正。

    .DESCRIPTION
        两种安装口径共用本函数，差别只在 `-ExistingOnly`：

        - 不带 `-ExistingOnly`（完整安装 / 首次安装）：清单声明了 shortcuts 就补齐——缺的建、
          指向不对的修、指向正确的不动。
        - 带 `-ExistingOnly`（「只更新文件」）：**只修正已经存在的快捷方式，不新建**。
          用户主动删掉的快捷方式不该在更新时又冒出来；但安装位置换过以后留在桌面 / 开始菜单里的
          旧快捷方式指向已不存在的程序，双击打不开，必须跟着改到新位置。

        判断「指向对不对」见 Test-WinstShortcutMatches（目标程序 + 起始位置）。
        所有失败都写进 Notes 返回，不抛异常——快捷方式建不出来不该让整次安装失败。

    .OUTPUTS
        @{ Applied; Repaired; Notes }
    #>
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [switch]$ExistingOnly
    )

    $applied = @()
    $repaired = @()
    $notes = @()

    $shortcutPaths = @(Get-WinstShortcutPaths -Plan $Plan)
    if ($shortcutPaths.Count -eq 0) {
        return @{ Applied = $applied; Repaired = $repaired; Notes = $notes }
    }

    $resolved = Resolve-WinstShortcutTarget -Plan $Plan -InstallDir $InstallDir
    if (-not $resolved.Target) {
        if ($resolved.Note) { $notes += $resolved.Note }
        return @{ Applied = $applied; Repaired = $repaired; Notes = $notes }
    }

    foreach ($link in $shortcutPaths) {
        $exists = Test-Path -LiteralPath $link -PathType Leaf

        if ($exists) {
            # 已存在：先判断是否还指向这个程序。指向正确就保留（不白写一次文件），
            # 指向不对（安装位置换过 / 旧版本残留 / 被手工改过）必须覆盖修正，
            # 否则用户双击的是「打不开的快捷方式」。
            if (Test-WinstShortcutMatches -LinkPath $link -TargetPath $resolved.Target -WorkingDirectory $resolved.WorkingDirectory) {
                $notes += ('快捷方式已存在且指向正确，已保留: {0}' -f $link)
                $applied += $link
                continue
            }
            try {
                New-WinstShortcutFile -LinkPath $link -TargetPath $resolved.Target `
                    -WorkingDirectory $resolved.WorkingDirectory -Description $resolved.DisplayName
                $applied += $link
                $repaired += $link
                $notes += ('快捷方式指向不正确，已修正: {0}' -f $link)
            } catch {
                $notes += ('修正快捷方式失败（{0}）：{1}' -f $link, $_.Exception.Message)
            }
            continue
        }

        if ($ExistingOnly) {
            # 用户删掉了 / 从没建过：只更新文件的口径下不补建，也不刷提示（每次更新都提一遍太吵）
            continue
        }

        try {
            New-WinstShortcutFile -LinkPath $link -TargetPath $resolved.Target `
                -WorkingDirectory $resolved.WorkingDirectory -Description $resolved.DisplayName
            $applied += $link
        } catch {
            $notes += ('创建快捷方式失败（{0}）：{1}' -f $link, $_.Exception.Message)
        }
    }

    return @{ Applied = $applied; Repaired = $repaired; Notes = $notes }
}
