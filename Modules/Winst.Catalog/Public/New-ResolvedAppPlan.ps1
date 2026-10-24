#Requires -Version 5.1

function New-ResolvedAppPlan {
    <#
    .SYNOPSIS
        由清单条目 + 来源解析结果生成单个软件的「全流程实际内容」，作为解析锁的一条记录。
    .DESCRIPTION
        覆盖七个阶段：① 下载 ② 解压/安装 ③ 复制/移动 ④ 设置环境变量
        ⑤ 执行预定义命令 ⑥ 检测版本号 ⑦ 卸载操作。{version} 展开为具体版本，
        {installDir} 与 %VAR% 保留符号（安装时按本机 installRoot 展开）。
        本函数只做编排：各阶段由 New-WinstPlan* 按类型生成片段后在这里组装。
    #>
    param(
        [string]$ManifestOrigin,
        $Entry,
        $Resolve,
        [string]$PkgDir = '',
        $Context = $null
    )

    $base = New-WinstPlanBase -ManifestOrigin $ManifestOrigin -Entry $Entry -Resolve $Resolve
    $plan = $base.Plan
    if ($base.Error) { return $plan }

    $versionState = Resolve-WinstPlanVersion -Plan $plan -Entry $Entry -PkgDir $PkgDir -Context $Context -Notes $base.Notes
    if ($versionState.Error) { return $plan }
    $version = [string]$versionState.Version
    $notes = @($versionState.Notes)

    $type = [string]$plan['type']
    $displayName = [string]$plan['name']
    $fileList = @($plan['download']['files'])

    # ③ 复制 / 改名 ④ 环境变量 / PATH / 快捷方式 ⑤ 安装后命令 ⑥ 版本检测
    # 先按通用口径算出来；installer / download 分支随后按类型覆盖（与拆分前的顺序一致）
    $copyResult = New-WinstPlanCopyBlock -Entry $Entry -Version $version
    if ($copyResult.Error) { $plan['error'] = $copyResult.Error; return $plan }
    $copyList = @($copyResult.Items)
    $system = New-WinstPlanSystemBlock -Entry $Entry -Version $version
    $postList = @(New-WinstPlanPostInstallBlock -Entry $Entry -Version $version)
    $detectResult = New-WinstPlanDetectBlock -Entry $Entry -Version $version -Type $type -DisplayName $displayName
    if ($detectResult.Error) { $plan['error'] = $detectResult.Error; return $plan }
    $detectBlock = $detectResult.Block

    $envMap = $system.Env
    $pathList = $system.Path
    $desktop = [bool]$system.Desktop
    $startMenu = [bool]$system.StartMenu
    $shortcutName = ''

    # ② 解压 / 安装 与 ⑦ 卸载
    if ($type -eq 'installer') {
        $blocks = New-WinstInstallerBlocks -Entry $Entry -Version $version -FileList $fileList -DetectBlock $detectBlock
        if ($blocks.Error) { $plan['error'] = $blocks.Error; return $plan }
        $installBlock = $blocks.Install
        $uninstallBlock = $blocks.Uninstall
        foreach ($note in @($blocks.Notes)) { $notes += $note }
        # 安装版软件的系统项由安装程序自己管理：清空 ③④⑤ 的结果（与拆分前一致）
        $envMap = [ordered]@{}
        $pathList = @()
        $copyList = @()
        $postList = @()
        $desktop = $false
        $startMenu = $false
    } elseif ($type -eq 'download') {
        $installBlock = [ordered]@{ method = 'download' }
        $uninstallBlock = [ordered]@{ method = 'clean-cache' }
        $detectBlock = [ordered]@{ method = 'none' }
        $envMap = [ordered]@{}
        $pathList = @()
        $copyList = @()
        $postList = @()
        $desktop = $false
        $startMenu = $false
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

    # ⑦′ 卸载命令：删安装目录 / 跑官方卸载器**之前**执行
    # （如 MPC-VR 用 `regsvr32 /u` 注销 DirectShow 滤镜——注销要求 .ax 还在原地）；download 类型不适用
    if ($type -ne 'download') {
        Add-WinstPlanUninstallCommands -Uninstall $uninstallBlock -Entry $Entry -Version $version
    }

    $plan['download']['files'] = $fileList
    $plan['install'] = $installBlock
    $plan['postInstallCopy'] = $copyList
    $plan['env'] = $envMap
    $plan['addToPath'] = $pathList
    $plan['shortcuts'] = [ordered]@{ desktop = $desktop; startMenu = $startMenu }
    $plan['postInstall'] = $postList
    $plan['detect'] = $detectBlock
    $plan['uninstall'] = $uninstallBlock
    $plan['notes'] = $notes

    # 无法获取最新版本号的条目：解析时顺手发一次 HEAD，
    # 比对「远端文件」与「缓存索引里上次下载的记账」（ETag / Last-Modified / 长度），结论存进解析锁
    # （remoteFresh：changed / unchanged / unknown）——各列表 / 详情据此提示「远端有新包」，
    # 展示时读锁即可、零网络请求；HEAD 失败 / 没有基线时如实记 unknown，不猜测
    if ([bool]$plan['versionFromPackage']) {
        Set-WinstPlanRemoteFresh -Plan $plan -PkgDir $PkgDir -Context $Context
    }

    $plan['ok'] = $true
    return $plan
}
