#Requires -Version 5.1

function Copy-WinstBundleSupportFiles {
    <#
    .SYNOPSIS
        ⑧ 复制软件源清单数据 / 脚本与模块 / 生成安装清单与 winst.cmd。
    .OUTPUTS
        @{ Ok; Error; ManifestCopied }
    #>
    param([hashtable]$Context, [string]$TargetDir, [string]$KitAppsDir, [string]$ListTarget, [string[]]$CommentLines, $Plan, [switch]$DryRun)

    $manifestCopied = 0
    $srcManifestDir = Get-ManifestRootDir -PkgDir $Context.PkgDir
    if (Test-Path -LiteralPath $srcManifestDir -PathType Container) {
        if (-not $DryRun) {
            try {
                Assert-WinstSafeWritePath -Path $KitAppsDir -Directory
                if (-not (Test-Path -LiteralPath $KitAppsDir -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $KitAppsDir -Force -ErrorAction Stop
                }
                $manifestCopied = Copy-WinstBundleItem -Source $srcManifestDir -Destination (Join-WinstPath $KitAppsDir 'manifests') -CountFiles
            } catch {
                $errorText = '复制软件源清单数据失败: {0}' -f $_.Exception.Message
                return @{ Ok = $false; Error = $errorText }
            }
        } else {
            Write-Host ('  将复制软件源清单数据: {0}  ->  {1}' -f $srcManifestDir, (Join-WinstPath $KitAppsDir 'manifests')) -ForegroundColor Gray
        }
    }

    $scriptDir = [string](Get-WinstState -Name WinstScriptDir)
    $mainScript = Join-WinstPath $scriptDir 'winst.ps1'
    $modulesDir = Join-WinstPath $scriptDir 'Modules'
    $licensePath = Join-WinstPath $scriptDir 'LICENSE'
    if (-not $scriptDir -or -not (Test-Path -LiteralPath $mainScript -PathType Leaf) -or
        -not (Test-Path -LiteralPath $modulesDir -PathType Container) -or
        -not (Test-Path -LiteralPath $licensePath -PathType Leaf)) {
        return @{ Ok = $false; Error = '当前 winst 的脚本、Modules 或 LICENSE 不完整，无法制作套件。' }
    }
    if (-not $DryRun) {
        try {
            Copy-WinstBundleItem -Source $mainScript -Destination (Join-WinstPath $TargetDir 'winst.ps1')
            Copy-WinstBundleItem -Source $licensePath -Destination (Join-WinstPath $TargetDir 'LICENSE')
            $targetModules = Join-WinstPath $TargetDir 'Modules'
            Assert-WinstSafeWritePath -Path $targetModules -Directory
            # 先确认目标不包含当前运行的模块，避免自复制时删除来源。
            if ((Test-WinstPathUnderRoot -Path $modulesDir -Root $targetModules -AllowEqual) -or
                (Test-WinstPathUnderRoot -Path $targetModules -Root $modulesDir -AllowEqual)) {
                throw '套件 Modules 目录不能与当前运行的 Modules 目录重叠。'
            }
            Assert-WinstTreeWithoutReparsePoint -Path $modulesDir
            if (Test-Path -LiteralPath $targetModules) {
                Clear-WinstInstallDir -Dir $targetModules -AllowedRoot $TargetDir
                if (Test-Path -LiteralPath $targetModules) { throw ('无法安全替换套件 Modules 目录：{0}' -f $targetModules) }
            }
            Copy-Item -LiteralPath (ConvertTo-WinstExtendedPath -Path $modulesDir) -Destination (ConvertTo-WinstExtendedPath -Path $targetModules) -Recurse -Force -ErrorAction Stop

            $scriptManifest = Join-WinstPath $scriptDir 'manifest.json'
            if (Test-Path -LiteralPath $scriptManifest -PathType Leaf) {
                Copy-WinstBundleItem -Source $scriptManifest -Destination (Join-WinstPath $TargetDir 'manifest.json')
            }
            $scriptManifestDir = Join-WinstPath $scriptDir 'manifests'
            if (Test-Path -LiteralPath $scriptManifestDir -PathType Container) {
                Copy-WinstBundleItem -Source $scriptManifestDir -Destination (Join-WinstPath $TargetDir 'manifests')
            }
        } catch {
            $errorText = '复制脚本 / 模块 / 本地清单失败: {0}' -f $_.Exception.Message
            return @{ Ok = $false; Error = $errorText }
        }
    } else {
        Write-Host ('  将复制脚本、模块与本地清单: {0}  ->  {1}' -f $scriptDir, $TargetDir) -ForegroundColor Gray
    }

    try {
        Assert-WinstSafeWritePath -Path (Split-Path -Parent $ListTarget) -Directory
        $pins = New-WinstOrdinalDictionary
        foreach ($item in $Plan) { $pins[$item['Id']] = [string]$item['PinnedVersion'] }
        $saved = Save-WinstList -Path $ListTarget -Ids @($pins.Keys) -VersionById $pins -CommentLines $CommentLines -DryRun:$DryRun
        if (-not $saved.Ok) { throw $saved.Error }
        if ($DryRun) { Write-Host ('  将生成安装清单: {0}' -f $ListTarget) -ForegroundColor Gray }
    } catch {
        return @{ Ok = $false; Error = ('生成套件安装清单失败: {0}' -f $_.Exception.Message) }
    }

    # winst.cmd 双击启动器
    $cmdContent = (@(
        '@echo off',
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*'
    ) -join [Environment]::NewLine) + [Environment]::NewLine

    if ($DryRun) {
        Write-Host ('  将生成: {0}' -f (Join-WinstPath $TargetDir 'winst.cmd')) -ForegroundColor Gray
    } else {
        try {
            Write-FileAtomic -Path (Join-WinstPath $TargetDir 'winst.cmd') -Content $cmdContent
        } catch {
            $errorText = '写入启动器失败: {0}' -f $_.Exception.Message
            return @{ Ok = $false; Error = $errorText }
        }
    }

    return @{ Ok = $true; Error = ''; ManifestCopied = $manifestCopied }
}
