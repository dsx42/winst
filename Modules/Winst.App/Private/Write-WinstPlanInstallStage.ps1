#Requires -Version 5.1

function Write-WinstPlanInstallStage {
    <#
    .SYNOPSIS
        ② 安装段（portable / file / installer / download），返回主程序相对路径供 ⑥ 检测段使用。
    .OUTPUTS
        [string] 主程序（可能为空）
    #>
    param($Plan, [hashtable]$View)

    $install = Get-EntryValue -Entry $Plan -Key 'install' -Default $null
    $installDir = $View.InstallDir
    $installLines = @()
    $mainProgram = ''
    switch (Get-EntryString -Entry $install -Key 'method') {
        'portable' {
            $installLines += ('解压到: {0}' -f $installDir)
            $extractList = @(Get-EntryArray -Entry $install -Key 'extractFiles')
            if ($extractList.Count -gt 0) {
                # extractFiles 优先于 stripTopDir：只把包内这几个路径落地（引擎包只取 7z.exe + 7z.dll）
                $installLines += ('解压方式: 只取压缩包里的 {0}' -f (($extractList | ForEach-Object { '"{0}"' -f [string]$_ }) -join '、'))
            } else {
                $installLines += ('解压方式: ' + (Get-WinstStripTopDirText -Install $install))
            }

            $modeText = '先删掉旧目录再解压'
            if ((Get-EntryString -Entry $install -Key 'portableMode') -eq 'overwrite') { $modeText = '直接覆盖旧文件' }
            $keepCount = @(Get-EntryArray -Entry $install -Key 'keep').Count
            $modeLine = ('重新安装时: ' + $modeText)
            if ($keepCount -gt 0) { $modeLine += ('，保留 {0} 项内容' -f $keepCount) }
            $installLines += $modeLine

            $mainProgram = Get-EntryString -Entry $install -Key 'mainExe'
        }
        'file' {
            $installLines += ('复制到: {0}' -f $installDir)
            $mainProgram = Get-EntryString -Entry $install -Key 'mainExe'
        }
        'installer' {
            if (Get-EntryBool -Entry $install -Key 'appx') {
                # 应用包（msixbundle 等）：由系统自带的应用包安装完成，不复制到安装目录
                $installLines += '作为应用包安装（系统自带的应用包安装，不复制到软件安装目录）'
            } else {
                $installLines += '运行安装程序，自动完成安装'
            }
            $installerExe = Get-EntryString -Entry $install -Key 'installerExe'
            if ($installerExe) {
                $stripText = Get-WinstStripTopDirText -Install $install
                $installLines += ('安装包是压缩包：先解压（{0}），再运行包内的 {1}' -f $stripText, $installerExe)
            }
            $argumentExpansion = Expand-WinstInstallerArguments -Template (Get-EntryString -Entry $install -Key 'installArgs') `
                -InstallDir $installDir -InstallRoot $View.InstallRoot
            $installArgs = ''
            if ($argumentExpansion.Ok) { $installArgs = [string]$argumentExpansion.Value }
            else { $installArgs = Get-EntryString -Entry $install -Key 'installArgs' }
            if ($installArgs) { $installLines += ('安装参数: {0}' -f $installArgs) }
            # 安装位置由安装程序决定：只有安装命令里写明了安装路径才展示预期位置，否则不猜（见 Get-WinstInstallerExpectedDir）
            $expectedDir = Get-WinstInstallerExpectedDir -Plan $Plan -InstallArgs $installArgs -InstallDir $installDir
            if ($expectedDir) { $installLines += ('安装位置: 预期装到 {0}' -f $expectedDir) }
        }
        'download' {
            $installLines += '只把安装包保存下来，不安装到电脑上'
        }
        default { $installLines += '（无法识别的安装方式）' }
    }
    if ($mainProgram) {
        $mainFull = $mainProgram
        if ($installDir -and -not [IO.Path]::IsPathRooted($mainFull)) { $mainFull = Join-WinstPath $installDir $mainFull }
        $installLines += ('主程序: {0}' -f $mainFull)
    }
    Write-ResolvedStage -Marker '②' -Label '安装' -Lines $installLines
    return $mainProgram
}
