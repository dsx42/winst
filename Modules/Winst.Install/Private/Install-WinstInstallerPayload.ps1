#Requires -Version 5.1

function Install-WinstInstallerPayload {
    <#
    .SYNOPSIS
        从缓存路径安装主包。声明 installerExe 时，先解到固定暂存并定位安装程序。
    .OUTPUTS
        @{ Ok; Error; InstallDir }
    #>
    param([hashtable]$Context, $Plan, $Install, [string]$InstallDir, [string]$PrimaryPath, $Ledger, [string]$Id, [switch]$Quiet)

    $work = $PrimaryPath
    $unpackDir = ''
    $result = @{ Ok = $false; Error = ''; InstallDir = $InstallDir }
    try {
        $installerExeRel = (Get-EntryString -Entry $Install -Key 'installerExe').Trim()
        if ($installerExeRel) {
            $engine = Confirm-WinstExtractEngine -Context $Context -Quiet:$Quiet
            if (-not $engine.Ok) { throw ('解压引擎不可用：{0}' -f $engine.Error) }
            $stripValue = Get-EntryValue -Entry $Install -Key 'stripTopDir' -Default $true
            $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $PrimaryPath -DestDir $InstallDir -StripTopDir $stripValue
            if (-not $layout.Ok) { throw ('解压安装包 {0} 失败：{1}' -f (Split-Path -Leaf $PrimaryPath), $layout.Error) }

            $unpackDir = [string]$layout.TempRoot
            $installerResolved = Resolve-WinstSafeChildPattern -Root ([string]$layout.SourceDir) -Child $installerExeRel -Label 'installerExe'
            if (-not $installerResolved.Ok) { throw $installerResolved.Error }
            $found = @(Get-Item -Path $installerResolved.Path -Force -ErrorAction SilentlyContinue)
            if ($found.Count -eq 0) {
                $missing = '解压后的安装包里没有找到安装程序「{0}」（安装包: {1}）' -f $installerExeRel, (Split-Path -Leaf $PrimaryPath)
                if (Get-EntryBool -Entry (Get-WinstState -Name WinstOptions) -Key 'Offline') {
                    throw ('无法离线安装 {0}，当前计划与缓存包内容不符：{1}' -f $Id, $missing)
                }
                throw $missing
            }
            if ($found.Count -gt 1) { throw ('「{0}」在安装包里命中了多个文件，无法确定要运行哪一个' -f $installerExeRel) }
            $work = $found[0].FullName
            if (-not (Test-Path -LiteralPath $work -PathType Leaf) -or (Test-WinstPathHasReparsePoint -Path $work -Root $unpackDir)) {
                throw ('拒绝运行重解析点或非文件安装程序：{0}' -f $work)
            }
        }

        $argumentExpansion = Expand-WinstInstallerArguments -Template (Get-EntryString -Entry $Install -Key 'installArgs') `
            -InstallDir $InstallDir -InstallRoot $Context.InstallRoot
        if (-not (Test-WinstArgumentSafe -Value $work)) {
            throw ('安装包路径含有无法安全传给安装程序的字符（双引号 / 控制字符）：{0}' -f $work)
        }
        if (-not $argumentExpansion.Ok) { throw ('软件源里的安装参数无法安全展开：{0}' -f $argumentExpansion.Error) }
        $argsText = [string]$argumentExpansion.Value
        $ext = [IO.Path]::GetExtension($work)
        Invoke-WinstFileStep -Name '安装' -Quiet:$Quiet -Action {
            if ($ext -in @('.msix', '.msixbundle', '.appx', '.appxbundle')) {
                if (-not (Get-Command Add-AppxPackage -ErrorAction SilentlyContinue)) {
                    throw '系统里没有可用的应用包管理命令（Add-AppxPackage），无法安装这个应用包'
                }
                try { Add-AppxPackage -Path $work -ErrorAction Stop }
                catch { throw ('安装应用包失败：{0}' -f $_.Exception.Message) }
                return
            }

            $params = @{ FilePath = $work; Wait = $true; PassThru = $true; ErrorAction = 'Stop' }
            if ($ext -eq '.msi') {
                $params.FilePath = 'msiexec.exe'
                $msiArgs = '/i {0} TARGETDIR={1} /qn' -f (Format-WinstCommandArgument -Value $work), (Format-WinstCommandArgument -Value $InstallDir)
                if ($argsText) { $msiArgs += ' ' + $argsText }
                $params['ArgumentList'] = $msiArgs
            } elseif ($argsText) {
                $params['ArgumentList'] = $argsText
                # 静默运行控制台安装器时隐藏新窗口；交互式安装器保留窗口。
                if ($argsText -match '(?i)(^|\s)(/[sq]|/(quiet|qn|silent|verysilent|passive)|-(quiet|q|silent)|--(quiet|silent))(\s|$)') {
                    $params['WindowStyle'] = 'Hidden'
                }
            }
            try { $process = Start-Process @params }
            catch { throw ('运行安装程序失败：{0}' -f $_.Exception.Message) }
            $exitCode = $process.ExitCode
            if ($null -eq $exitCode) { throw '读不到安装程序退出码，无法确认安装成功，请检查安装结果后重试。' }
            if ([int]$exitCode -notin @(0, 1641, 3010)) { throw ('安装程序返回失败（退出码 {0}）' -f $exitCode) }
            if ([int]$exitCode -ne 0 -and -not $Quiet) {
                Write-Host '    安装程序提示需要重启电脑才能完成，请稍后重启。' -ForegroundColor DarkYellow
            }
        }

        # 回读安装结果前，先清除安装前的注册表和应用包快照。
        Reset-WinstSystemCache
        $appxCleanup = Remove-WinstAppxOutdatedPackages -Context $Context -Plan $Plan -Quiet:$Quiet
        if (-not $Quiet) {
            if (@($appxCleanup.Removed).Count -gt 0) {
                Write-Host ('    已清理旧版本应用包 {0} 个。' -f @($appxCleanup.Removed).Count) -ForegroundColor Gray
            }
            if (-not $appxCleanup.Ok) {
                Write-Host ('    提示: {0}' -f $appxCleanup.Error) -ForegroundColor DarkYellow
            }
        }
        $result.InstallDir = Update-WinstInstallDirAfterInstall -Context $Context -Plan $Plan -InstallDir $InstallDir -Ledger $Ledger `
            -Id $Id -InstallArgs $argsText -Quiet:$Quiet
        $result.Ok = $true
    } catch {
        $result.Error = $_.Exception.Message
    } finally {
        if ($unpackDir) {
            try { Invoke-WinstFileStep -Name '删暂存' -Action { Remove-WinstDirectoryTree -Path $unpackDir } }
            catch {
                $detail = ('安装包暂存清理失败（{0}）：{1}' -f $unpackDir, $_.Exception.Message)
                if ($result.Ok) { $result.Error = '安装程序已完成，' + $detail }
                else { $result.Error += '；' + $detail }
                $result.Ok = $false
            }
        }
    }
    return $result
}
