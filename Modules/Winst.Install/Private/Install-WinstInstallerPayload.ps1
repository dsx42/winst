#Requires -Version 5.1

function Install-WinstInstallerPayload {
    <#
    .SYNOPSIS
        ② installer：压缩包先解出 installerExe → msiexec / 安装程序 / Add-AppxPackage → 清应用包残留 → 回读实际安装目录。
    .OUTPUTS
        @{ Ok; Error; InstallDir }
    #>
    param([hashtable]$Context, $Plan, $Install, [string]$InstallDir, [string]$PrimaryPath, $Ledger, [string]$Id, [switch]$Quiet)

    $work = $PrimaryPath
    if ($work.StartsWith('\\')) {
        $local = Join-WinstPath ([IO.Path]::GetTempPath()) (Split-Path -Leaf $work)
        try { Copy-Item -LiteralPath $work -Destination $local -Force -ErrorAction Stop; $work = $local } catch { }
    }

    # 主包是压缩包（如 Chocolatey 的 .nupkg）：声明 installerExe 时先解压，再运行包内的安装程序
    $unpackDir = ''
    $installerExeRel = (Get-EntryString -Entry $Install -Key 'installerExe').Trim()
    if ($installerExeRel) {
        $null = Confirm-WinstExtractEngine -Context $Context -Quiet:$Quiet
        $unpackDir = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-inst-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        $stripValue = Get-EntryValue -Entry $Install -Key 'stripTopDir' -Default $true
        if ($null -eq $stripValue) { $stripValue = $true }

        $layout = Expand-WinstArchiveLayout -Context $Context -ArchivePath $work -DestDir $unpackDir -StripTopDir $stripValue
        if (-not $layout.Ok) {
            if (Test-Path -LiteralPath $unpackDir) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = ('解压安装包 {0} 失败：{1}' -f (Split-Path -Leaf $work), $layout.Error); InstallDir = $InstallDir }
        }

        $installerResolved = Resolve-WinstSafeChildPattern -Root $unpackDir -Child $installerExeRel -Label 'installerExe'
        if (-not $installerResolved.Ok) {
            if (Test-Path -LiteralPath $unpackDir) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = [string]$installerResolved.Error; InstallDir = $InstallDir }
        }
        $found = @()
        try { $found = @(Get-Item -Path $installerResolved.Path -Force -ErrorAction SilentlyContinue) } catch { $found = @() }
        if ($found.Count -eq 0) {
            if (Test-Path -LiteralPath $unpackDir) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = ('解压后的安装包里没有找到安装程序「{0}」（安装包: {1}）' -f $installerExeRel, (Split-Path -Leaf $work)); InstallDir = $InstallDir }
        }
        if ($found.Count -gt 1) {
            if (Test-Path -LiteralPath $unpackDir) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = ('「{0}」在安装包里命中了多个文件，无法确定要运行哪一个' -f $installerExeRel); InstallDir = $InstallDir }
        }
        if (-not (Test-Path -LiteralPath $found[0].FullName -PathType Leaf) -or
                (Test-WinstPathHasReparsePoint -Path $found[0].FullName -Root $unpackDir)) {
            if (Test-Path -LiteralPath $unpackDir) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = ('拒绝运行重解析点或非文件安装程序：{0}' -f $found[0].FullName); InstallDir = $InstallDir }
        }

        $work = $found[0].FullName
        if (-not $Quiet) { Write-Host ('    安装包是压缩包，已解压出安装程序 {0}' -f $found[0].Name) -ForegroundColor Gray }
    }

    $argumentExpansion = Expand-WinstInstallerArguments -Template (Get-EntryString -Entry $Install -Key 'installArgs') `
        -InstallDir $InstallDir -InstallRoot $Context.InstallRoot
    if (-not (Test-WinstArgumentSafe -Value $work) -or -not (Test-WinstArgumentSafe -Value $InstallDir)) {
        if ($unpackDir -and (Test-Path -LiteralPath $unpackDir)) { Clear-WinstInstallDir -Dir $unpackDir }
        return @{ Ok = $false; Error = ('安装包路径或安装目录含有无法安全传给安装程序的字符（双引号 / 控制字符）：{0}' -f $work); InstallDir = $InstallDir }
    }
    if (-not $argumentExpansion.Ok) {
        if ($unpackDir -and (Test-Path -LiteralPath $unpackDir)) { Clear-WinstInstallDir -Dir $unpackDir }
        return @{ Ok = $false; Error = ('软件源里的安装参数无法安全展开：{0}' -f $argumentExpansion.Error); InstallDir = $InstallDir }
    }
    $argsText = [string]$argumentExpansion.Value
    $ext = ''
    try { $ext = [IO.Path]::GetExtension($work).ToLowerInvariant() } catch { $ext = '' }

    if (@('.msix', '.msixbundle', '.appx', '.appxbundle') -contains $ext) {
        # 应用包（msixbundle 等）：交给系统自带的应用包安装（Add-AppxPackage），不运行安装程序、
        # 也不往安装目录里复制；这类条目的安装位置由 detect.method = appx 从系统记录里读
        if (-not (Get-Command Add-AppxPackage -ErrorAction SilentlyContinue)) {
            return @{ Ok = $false; Error = '系统里没有可用的应用包管理命令（Add-AppxPackage），无法安装这个应用包'; InstallDir = $InstallDir }
        }
        if (-not $Quiet) { Write-Host ('    正在安装应用包 {0} …' -f (Split-Path -Leaf $work)) -ForegroundColor Gray }
        try {
            Add-AppxPackage -Path $work -ErrorAction Stop
            # 新包已落地：让 Appx 快照失效，安装后的版本检测必须读到它
            $null = Set-WinstState -Name WinstAppxCache -Value ($null)
        } catch {
            return @{ Ok = $false; Error = ('安装应用包失败：{0}' -f $_.Exception.Message); InstallDir = $InstallDir }
        }
    } else {
        if (-not $Quiet) { Write-Host ('    正在运行安装程序 {0} …' -f (Split-Path -Leaf $work)) -ForegroundColor Gray }
        try {
            $exitCode = 0
            if ($ext -eq '.msi') {
                # 逐项加引号：路径含空格时 `/i "C:\Program Files\x.msi"` 才不会被拆成多个参数；
                # TARGETDIR 只把值加引号（msiexec 的公共属性写法）；清单给的 installArgs 原样附在后面
                $msiParts = @(
                    '/i',
                    (Format-WinstCommandArgument -Value $work),
                    ('TARGETDIR=' + (Format-WinstCommandArgument -Value $InstallDir)),
                    '/qn'
                )
                $msiArgs = ($msiParts -join ' ')
                if ($argsText) { $msiArgs += ' ' + $argsText }
                $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru
                $exitCode = $p.ExitCode
            } else {
                $params = @{ FilePath = $work; Wait = $true; PassThru = $true }
                if ($argsText) { $params['ArgumentList'] = $argsText }
                # 控制台类安装器（如 Windows App SDK 运行时安装器）就算带了静默参数，
                # Start-Process 默认仍会弹出新的控制台窗口——安装参数里带静默标记时隐藏窗口；
                # 没写静默参数的交互式安装器保持原样、不隐藏
                if ($argsText -match '(?i)(^|\s)(/[sq]|/(quiet|qn|silent|verysilent|passive)|-(quiet|q|silent)|--(quiet|silent))(\s|$)') {
                    $params['WindowStyle'] = 'Hidden'
                }
                $p = Start-Process @params
                $exitCode = $p.ExitCode
            }
        } catch {
            return @{ Ok = $false; Error = ('运行安装程序失败：{0}' -f $_.Exception.Message); InstallDir = $InstallDir }
        }
        # 0 = 成功；1641 = 已发起重启（MSI/大量 exe 安装器常用）；3010 = 需重启才能完成
        if ($null -eq $exitCode) {
            if ($unpackDir -and (Test-Path -LiteralPath $unpackDir)) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = '读不到安装程序退出码，无法确认安装成功，请检查安装结果后重试。'; InstallDir = $InstallDir }
        } elseif (@(0, 1641, 3010) -notcontains [int]$exitCode) {
            if ($unpackDir -and (Test-Path -LiteralPath $unpackDir)) { Clear-WinstInstallDir -Dir $unpackDir }
            return @{ Ok = $false; Error = ('安装程序返回失败（退出码 {0}）' -f $exitCode); InstallDir = $InstallDir }
        } elseif ([int]$exitCode -ne 0 -and -not $Quiet) {
            Write-Host '    安装程序提示需要重启电脑才能完成，请稍后重启。' -ForegroundColor DarkYellow
        }
    }
    if ($unpackDir -and (Test-Path -LiteralPath $unpackDir)) {
        Clear-WinstInstallDir -Dir $unpackDir
    }

    # 安装器刚写完系统记录：立刻让注册表 / Appx 快照失效，
    # 否则下面 Update-WinstInstallDirAfterInstall 与随后的版本检测会读到安装前的旧快照
    Reset-WinstSystemCache

    # —— 应用包残留清点（卸载方式为 appx 的条目）：安装 / 升级完成后，把「版本低于本次检出版本」的
    # 残留包清掉——Windows App SDK 的 DDLM 包按版本命名，旧版本的 DDLM 安装器不会删、会越积越多
    # （如 DDLM.2.4.0.0）；清理失败不阻断安装，只给提示 ——
    $appxCleanup = Remove-WinstAppxOutdatedPackages -Context $Context -Plan $Plan -Quiet:$Quiet
    if (-not $Quiet) {
        if (@($appxCleanup.Removed).Count -gt 0) {
            Write-Host ('    已清理旧版本应用包 {0} 个。' -f @($appxCleanup.Removed).Count) -ForegroundColor Gray
        }
        if (-not $appxCleanup.Ok) {
            Write-Host ('    提示: {0}' -f $appxCleanup.Error) -ForegroundColor DarkYellow
        }
    }

    return (Update-WinstInstallDirAfterInstall -Context $Context -Plan $Plan -InstallDir $InstallDir -Ledger $Ledger `
            -Id $Id -InstallArgs $argsText -Quiet:$Quiet)
}
