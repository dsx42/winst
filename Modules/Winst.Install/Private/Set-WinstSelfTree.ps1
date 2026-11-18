#Requires -Version 5.1

function Set-WinstSelfTree {
    <#
    .SYNOPSIS
        用 release 压缩包的内容替换 winst 安装目录。

    .PARAMETER InstallDir
        目标目录，通常是 <installRoot>\winst。

    .PARAMETER ArchivePath
        release 压缩包。为空时改用 SourceDir 或 FallbackSourcePath。

    .PARAMETER SourceDir
        已解压的包目录。用它代替再解压一次压缩包，
        使一行安装脚本不必把同一个 zip 解开两遍。

    .PARAMETER FallbackSourcePath
        没有压缩包时使用的 winst.ps1 路径；同时复制其相邻 Modules、winst.cmd 与 LICENSE。
        运行树不完整时明确失败。

    .OUTPUTS
        @{ Ok; Error }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [string]$ArchivePath = '',
        [string]$SourceDir = '',
        [string]$FallbackSourcePath = ''
    )

    $result = @{ Ok = $false; Error = '' }

    $staging = ''
    $stageChecked = $false

    # 树从哪来，仅用于报错文案。调用方传的是已解压的 SourceDir 时
    # ArchivePath 可能为空。
    $sourceLabel = $ArchivePath
    if (-not $sourceLabel) { $sourceLabel = $SourceDir }
    if (-not $sourceLabel) { $sourceLabel = $FallbackSourcePath }

    try {
        $InstallDir = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
        Assert-WinstSafeWritePath -Path $InstallDir -Directory
        $parent = [IO.Path]::GetTempPath()
        $staging = Join-WinstPath $parent ('winst-self-' + [Guid]::NewGuid().ToString('N'))
        Assert-WinstSafeWritePath -Path $staging -Directory
        $null = New-Item -ItemType Directory -Path $staging -Force -ErrorAction Stop

        # ---------------------------------------------------------- 取得树
        if ($SourceDir -and (Test-Path -LiteralPath $SourceDir -PathType Container)) {
            Assert-WinstTreeWithoutReparsePoint -Path $SourceDir
            # 调用方已经解压过：直接复制树，不再把同一个压缩包解一遍。
            foreach ($item in @(Get-ChildItem -LiteralPath $SourceDir -Force -ErrorAction Stop)) {
                Copy-Item -LiteralPath $item.FullName -Destination (Join-WinstPath $staging $item.Name) -Recurse -Force -ErrorAction Stop
            }
        } elseif ($ArchivePath -and (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
            $expand = Expand-WinstPackageArchive -Context $null -ArchivePath $ArchivePath -DestDir $staging
            if (-not $expand.Ok) {
                $result.Error = ('解压 winst 安装包失败：{0}' -f $expand.Error)
                return $result
            }
            $stageChecked = $true
        } elseif ($FallbackSourcePath -and (Test-Path -LiteralPath $FallbackSourcePath -PathType Leaf)) {
            # 离线首次引导也必须带完整运行树；单独复制入口脚本不能启动。
            $fallbackDir = Split-Path -Parent $FallbackSourcePath
            foreach ($required in @('winst.ps1', 'winst.cmd', 'LICENSE', 'Modules')) {
                $sourceItem = Join-WinstPath $fallbackDir $required
                if (-not (Test-Path -LiteralPath $sourceItem)) {
                    throw ('当前运行树缺少 {0}，请使用完整的 winst.zip 或解压目录安装。' -f $required)
                }
                Assert-WinstTreeWithoutReparsePoint -Path $sourceItem
                Copy-Item -LiteralPath $sourceItem -Destination (Join-WinstPath $staging $required) -Recurse -Force -ErrorAction Stop
            }
        } else {
            $result.Error = '没有可用的 winst 安装包'
            return $result
        }

        # ------------------------------------------------------- 校验树
        $stagedScript = Join-WinstPath $staging 'winst.ps1'
        if (-not (Test-Path -LiteralPath $stagedScript -PathType Leaf)) {
            $result.Error = ('winst 安装包里没有 winst.ps1（来源: {0}）' -f $sourceLabel)
            return $result
        }

        # 每一种安装来源都必须提供可运行的模块。
        if (-not $stageChecked) {
            Assert-WinstTreeWithoutReparsePoint -Path $staging
        }
        $stagedModules = Join-WinstPath $staging 'Modules'
        if (-not (Test-Path -LiteralPath $stagedModules -PathType Container)) { throw 'winst 安装包里没有 Modules 目录' }
        foreach ($required in @('winst.cmd', 'LICENSE')) {
            if (-not (Test-Path -LiteralPath (Join-WinstPath $staging $required) -PathType Leaf)) {
                throw ('winst 安装包缺少 ' + $required)
            }
        }
        $moduleDirs = @(Get-ChildItem -LiteralPath $stagedModules -Directory -ErrorAction Stop)
        if ($moduleDirs.Count -eq 0) { throw 'winst 安装包没有模块目录' }
        $sharedLoader = Join-WinstPath $stagedModules 'Import-WinstFunctionFiles.ps1'
        $hasSharedLoader = Test-Path -LiteralPath $sharedLoader -PathType Leaf
        foreach ($moduleDir in $moduleDirs) {
            $manifestPath = Join-WinstPath $moduleDir.FullName ($moduleDir.Name + '.psd1')
            $modulePath = Join-WinstPath $moduleDir.FullName ($moduleDir.Name + '.psm1')
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
                -not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
                throw ('winst 模块目录缺少同名清单或加载器：' + $moduleDir.FullName)
            }
            # 自包含加载器可独立工作，点源公共脚本的开发模块须同时交付它。
            if (-not $hasSharedLoader -and (Select-String -LiteralPath $modulePath -Quiet -Pattern '^\s*\.\s+.*[\\/]Import-WinstFunctionFiles\.ps1["'']?(?:\s|$)')) {
                throw ('winst 安装包缺少模块加载器依赖：' + $sharedLoader)
            }
            $null = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        }
        foreach ($scriptFile in @($stagedScript) + @(Get-ChildItem -LiteralPath $stagedModules -Recurse -File -ErrorAction Stop |
                Where-Object { $_.Extension -in @('.ps1', '.psm1', '.psd1') } | ForEach-Object { $_.FullName })) {
            $parseErrors = $null
            $null = [Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$parseErrors)
            if ($parseErrors) { throw ('安装包脚本语法错误（{0}）：{1}' -f $scriptFile, $parseErrors[0].Message) }
        }
        if (Test-Path -LiteralPath $InstallDir -PathType Container) {
            foreach ($item in @(Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction Stop)) {
                if ($item.Name -ine 'lists' -and ($item.PSIsContainer -or $item.Extension -ine '.list')) { continue }
                Assert-WinstTreeWithoutReparsePoint -Path $item.FullName
                $destination = Join-WinstPath $staging $item.Name
                if ($item.Name -ieq 'lists' -and -not $item.PSIsContainer) {
                    Copy-Item -LiteralPath $item.FullName -Destination $destination -Force -ErrorAction Stop
                    continue
                }
                if (Test-Path -LiteralPath $destination) {
                    if (Test-Path -LiteralPath $destination -PathType Container) { Clear-WinstInstallDir -Dir $destination -Strict }
                    else { Remove-WinstFileSystemItem -Path $destination -ErrorAction Stop }
                }
            }
        }
        $move = Move-WinstStagedInstall -StageDir $staging -InstallDir $InstallDir -Clean -Keep @('lists/', '*.list')
        if (-not $move.Ok) { throw $move.Error }
        $result.Ok = $true
        return $result
    } catch {
        $result.Error = ('展开 winst 安装包失败：{0}' -f $_.Exception.Message)
        return $result
    } finally {
        try {
            if ($staging -and (Test-Path -LiteralPath $staging)) { Clear-WinstInstallDir -Dir $staging -AllowedRoot $parent }
        } catch { }
    }
}
