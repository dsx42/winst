#Requires -Version 5.1

function Copy-WinstBundleSupportFiles {
    <#
    .SYNOPSIS
        ⑧ 复制软件源清单数据 / 脚本与模块 / 清单文件，写入套件索引并生成 winst.cmd。
    .OUTPUTS
        @{ Ok; Error; ManifestCopied; ListFileCount }
    #>
    param([hashtable]$Context, [string]$TargetDir, [string]$KitAppsDir, $KitIndex, [string]$ListPath, [switch]$DryRun)

    $manifestCopied = 0
    $srcManifestDir = Get-ManifestRootDir -PkgDir $Context.PkgDir
    if (Test-Path -LiteralPath $srcManifestDir -PathType Container) {
        if (-not $DryRun) {
            try {
                if (-not (Test-Path -LiteralPath $KitAppsDir -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $KitAppsDir -Force -ErrorAction Stop
                }
                Copy-Item -LiteralPath $srcManifestDir -Destination $KitAppsDir -Recurse -Force -ErrorAction Stop
                $manifestCopied = @(Get-ChildItem -LiteralPath (Join-WinstPath $KitAppsDir 'manifests') -Recurse -File -ErrorAction Stop).Count
            } catch {
                $errorText = '复制软件源清单数据失败: {0}' -f $_.Exception.Message
                Write-Host ('  ' + $errorText) -ForegroundColor Red
                return @{ Ok = $false; Error = $errorText; ManifestCopied = 0; ListFileCount = 0 }
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
        return @{ Ok = $false; Error = '当前 winst 的脚本、Modules 或 LICENSE 不完整，无法制作套件。'; ManifestCopied = $manifestCopied; ListFileCount = 0 }
    }
    if (-not $DryRun) {
        try {
            Copy-Item -LiteralPath $mainScript -Destination (Join-WinstPath $TargetDir 'winst.ps1') -Force -ErrorAction Stop
            Copy-Item -LiteralPath $licensePath -Destination (Join-WinstPath $TargetDir 'LICENSE') -Force -ErrorAction Stop
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
            Copy-Item -LiteralPath $modulesDir -Destination $targetModules -Recurse -Force -ErrorAction Stop

            $scriptManifest = Join-WinstPath $scriptDir 'manifest.json'
            if (Test-Path -LiteralPath $scriptManifest -PathType Leaf) {
                Copy-Item -LiteralPath $scriptManifest -Destination (Join-WinstPath $TargetDir 'manifest.json') -Force -ErrorAction Stop
            }
            $scriptManifestDir = Join-WinstPath $scriptDir 'manifests'
            if (Test-Path -LiteralPath $scriptManifestDir -PathType Container) {
                Copy-Item -LiteralPath $scriptManifestDir -Destination $TargetDir -Recurse -Force -ErrorAction Stop
            }
        } catch {
            $errorText = '复制脚本 / 模块 / 本地清单失败: {0}' -f $_.Exception.Message
            Write-Host ('  ' + $errorText) -ForegroundColor Red
            return @{ Ok = $false; Error = $errorText; ManifestCopied = $manifestCopied; ListFileCount = 0 }
        }
    } else {
        Write-Host ('  将复制脚本、模块与本地清单: {0}  ->  {1}' -f $scriptDir, $TargetDir) -ForegroundColor Gray
    }

    # 清单文件：只复制本次选中的那一份（U 盘上的 winst 打开就是同一份清单，其它清单不带过去）
    $listFileCount = 0
    $dstListsDir = Join-WinstPath $TargetDir 'lists'
    $listFileName = Split-Path -Leaf $ListPath
    if ($listFileName -and (Test-Path -LiteralPath $ListPath -PathType Leaf)) {
        if (-not $DryRun) {
            try {
                if (-not (Test-Path -LiteralPath $dstListsDir -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $dstListsDir -Force -ErrorAction Stop
                }
                Copy-Item -LiteralPath $ListPath -Destination (Join-WinstPath $dstListsDir $listFileName) -Force -ErrorAction Stop
                $listFileCount = 1
            } catch {
                $errorText = '复制清单文件失败: {0}' -f $_.Exception.Message
                Write-Host ('  ' + $errorText) -ForegroundColor Red
                return @{ Ok = $false; Error = $errorText; ManifestCopied = $manifestCopied; ListFileCount = 0 }
            }
        } else {
            Write-Host ('  将复制清单文件: {0} -> {1}' -f $listFileName, $dstListsDir) -ForegroundColor Gray
            $listFileCount = 1
        }
    }

    # 套件索引（只含本次相关条目；已有条目不删除）
    if (-not $DryRun) {
        try { Save-WinstCacheIndex -PkgDir $KitAppsDir -Index $KitIndex }
        catch {
            $errorText = '写入套件索引失败: {0}' -f $_.Exception.Message
            Write-Host ('  ' + $errorText) -ForegroundColor Red
            return @{ Ok = $false; Error = $errorText; ManifestCopied = $manifestCopied; ListFileCount = $listFileCount }
        }
    } else {
        Write-Host ('  将写入套件索引: {0}' -f (Get-WinstCacheIndexPath -PkgDir $KitAppsDir)) -ForegroundColor Gray
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
            Write-Host ('  ' + $errorText) -ForegroundColor Red
            return @{ Ok = $false; Error = $errorText; ManifestCopied = $manifestCopied; ListFileCount = $listFileCount }
        }
    }

    return @{ Ok = $true; Error = ''; ManifestCopied = $manifestCopied; ListFileCount = $listFileCount }
}
