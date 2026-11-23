#Requires -Version 5.1

function Complete-WinstInstallPlan {
    <#
    .SYNOPSIS
        根据清单条目和已确认的版本生成全部安装、检测和卸载步骤。
    #>
    param($Plan, $Entry, [string]$Version, $Notes)

    $type = [string]$plan['type']
    $displayName = [string]$plan['name']
    $fileList = @(Get-EntryArray -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files')

    # 只解析当前类型适用的阶段；被忽略字段不进入业务校验。
    $copyList = @()
    $postList = @()
    $envMap = [ordered]@{}
    $pathList = @()
    $desktop = $false
    $startMenu = $false
    $detectBlock = [ordered]@{ method = 'none' }
    if ($type -ne 'installer' -and $type -ne 'download') {
        $copyResult = New-WinstPlanCopyBlock -Entry $Entry -Version $version
        if ($copyResult.Error) { $plan['error'] = $copyResult.Error; return $plan }
        $copyList = @($copyResult.Items)
        $system = New-WinstPlanSystemBlock -Entry $Entry -Version $version
        $envMap = $system.Env
        $pathList = $system.Path
        $desktop = [bool]$system.Desktop
        $startMenu = [bool]$system.StartMenu
        $postList = @(New-WinstPlanCommandList -Commands @(Get-EntryArray -Entry $Entry -Key 'postInstall') -Version $version -Field 'postInstall')
    }
    if ($type -ne 'download') {
        $detectResult = New-WinstPlanDetectBlock -Entry $Entry -Version $version -Type $type -DisplayName $displayName
        if ($detectResult.Error) { $plan['error'] = $detectResult.Error; return $plan }
        $detectBlock = $detectResult.Block
    }
    $shortcutName = ''

    # ② 解压 / 安装 与 ⑦ 卸载
    if ($type -eq 'installer') {
        $blocks = New-WinstInstallerBlocks -Entry $Entry -Version $version -FileList $fileList -DetectBlock $detectBlock
        if ($blocks.Error) { $plan['error'] = $blocks.Error; return $plan }
        $installBlock = $blocks.Install
        $uninstallBlock = $blocks.Uninstall
        foreach ($note in @($blocks.Notes)) { $notes += $note }
    } elseif ($type -eq 'download') {
        $plan['processes'] = @()
        $installBlock = [ordered]@{ method = 'download' }
        $uninstallBlock = [ordered]@{ method = 'clean-cache' }
        # 「只下载软件包、不安装到电脑」不写进 notes：计划详情里已有「类型 + ② 安装 不适用」的
        # 固定说明（见 Show-WinstPlanDetail），再写一条纯重复
    } else {
        $portable = New-WinstPortableBlocks -Entry $Entry -Version $version -Type $type -DisplayName $displayName `
            -FileList $fileList -CopyList $copyList -Desktop $desktop -StartMenu $startMenu
        $installBlock = $portable.Install
        foreach ($note in @($portable.Notes)) { $notes += $note }
        $shortcutName = [string]$portable.ShortcutName
        $uninstallBlock = New-WinstPortableUninstallBlock -EnvMap $envMap -PathList $pathList -ShortcutName $shortcutName
    }

    if ($detectBlock['method'] -eq 'fileVersion' -and -not (Get-EntryString -Entry $detectBlock -Key 'pathGlob')) {
        $mainExe = Get-EntryString -Entry $installBlock -Key 'mainExe'
        if (-not $mainExe) {
            $plan['error'] = 'detect.pathGlob 未填写且没有可用主程序'
            return $plan
        }
        $detectBlock['pathGlob'] = '{installDir}\' + $mainExe
    }

    # ⑦′ 卸载命令：删安装目录 / 跑官方卸载器**之前**执行
    # （如 MPC-VR 用 `regsvr32 /u` 注销 DirectShow 滤镜——注销要求 .ax 还在原地）；download 类型不适用
    if ($type -ne 'download') {
        Add-WinstPlanUninstallCommands -Uninstall $uninstallBlock -Entry $Entry -Version $version
    }

    $plan['install'] = $installBlock
    $plan['postInstallCopy'] = $copyList
    $plan['env'] = $envMap
    $plan['addToPath'] = $pathList
    $plan['shortcuts'] = [ordered]@{ desktop = $desktop; startMenu = $startMenu }
    $plan['postInstall'] = $postList
    $plan['detect'] = $detectBlock
    $plan['uninstall'] = $uninstallBlock
    $plan['notes'] = $notes

    $plan['ok'] = $true
    return $plan
}
