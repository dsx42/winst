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
                $manifestCopied = @(Get-ChildItem -LiteralPath (Join-Path $KitAppsDir 'manifests') -Recurse -File -ErrorAction Stop).Count
            } catch {
                $errorText = '复制软件源清单数据失败: {0}' -f $_.Exception.Message
                Write-Host ('  ' + $errorText) -ForegroundColor Red
                return @{ Ok = $false; Error = $errorText; ManifestCopied = 0; ListFileCount = 0 }
            }
        } else {
            Write-Host ('  将复制软件源清单数据: {0}  ->  {1}' -f $srcManifestDir, (Join-Path $KitAppsDir 'manifests')) -ForegroundColor Gray
        }
    }

    $scriptDir = [string](Get-WinstState -Name WinstScriptDir)
    $mainScript = Join-Path $scriptDir 'winst.ps1'
    $modulesDir = Join-Path $scriptDir 'Modules'
    if (-not $scriptDir -or -not (Test-Path -LiteralPath $mainScript -PathType Leaf) -or
        -not (Test-Path -LiteralPath $modulesDir -PathType Container)) {
        return @{ Ok = $false; Error = '当前 winst 的脚本或 Modules 目录不存在，无法制作套件。'; ManifestCopied = $manifestCopied; ListFileCount = 0 }
    }
    if (-not $DryRun) {
        try {
            Copy-Item -LiteralPath $mainScript -Destination (Join-Path $TargetDir 'winst.ps1') -Force -ErrorAction Stop
            Copy-Item -LiteralPath $modulesDir -Destination (Join-Path $TargetDir 'Modules') -Recurse -Force -ErrorAction Stop

            $scriptManifest = Join-Path $scriptDir 'manifest.json'
            if (Test-Path -LiteralPath $scriptManifest -PathType Leaf) {
                Copy-Item -LiteralPath $scriptManifest -Destination (Join-Path $TargetDir 'manifest.json') -Force -ErrorAction Stop
            }
            $scriptManifestDir = Join-Path $scriptDir 'manifests'
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
    $dstListsDir = Join-Path $TargetDir 'lists'
    $listFileName = Split-Path -Leaf $ListPath
    if ($listFileName -and (Test-Path -LiteralPath $ListPath -PathType Leaf)) {
        if (-not $DryRun) {
            try {
                if (-not (Test-Path -LiteralPath $dstListsDir -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $dstListsDir -Force -ErrorAction Stop
                }
                Copy-Item -LiteralPath $ListPath -Destination (Join-Path $dstListsDir $listFileName) -Force -ErrorAction Stop
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
        'rem winst 离线套件：双击本文件即可打开 winst 菜单（无需联网）。',
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*'
    ) -join [Environment]::NewLine) + [Environment]::NewLine

    if ($DryRun) {
        Write-Host ('  将生成: {0}' -f (Join-Path $TargetDir 'winst.cmd')) -ForegroundColor Gray
    } else {
        try {
            Write-FileAtomic -Path (Join-Path $TargetDir 'winst.cmd') -Content $cmdContent
        } catch {
            $errorText = '写入启动器失败: {0}' -f $_.Exception.Message
            Write-Host ('  ' + $errorText) -ForegroundColor Red
            return @{ Ok = $false; Error = $errorText; ManifestCopied = $manifestCopied; ListFileCount = $listFileCount }
        }
    }

    return @{ Ok = $true; Error = ''; ManifestCopied = $manifestCopied; ListFileCount = $listFileCount }
}
