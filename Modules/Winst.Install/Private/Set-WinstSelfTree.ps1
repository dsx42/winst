#Requires -Version 5.1
<#
    Set-WinstSelfTree.ps1  (Winst.Install / Private)

    按 release 压缩包的内容铺开 winst 目录。

    release 包结构
    --------------
    release 是一个 zip，内含：
        winst.ps1
        winst.cmd
        LICENSE
        Modules\Winst\（单一模块：Winst.psd1 + Winst.psm1）

    也接受多模块布局（Modules\Winst.*\），校验只要求 Modules\ 下至少有一个模块清单。

    winst.cmd 随包提供，绝不能再生成一遍——重新生成会与随包版本悄悄分叉。

    为什么先暂存再合并
    ------------------
    安装目录常常正是 winst 当前运行的目录。就地删除后重新解压会干掉
    正在运行的脚本及其已加载的模块。因此：

        1. 把 zip 解压到临时暂存目录
        2. 校验暂存树确实是 winst release
        3. 删掉目标目录里的过期条目（用户数据与 release 提供的条目除外）
        4. 把暂存树复制覆盖到目标

    第 3 步保证升级干净：新版本已移除的模块不会永久留在磁盘上被再次导入。

    保留的用户数据
    --------------
    安装目录下的 lists\ 与 *.list。这些是用户自己写的安装清单，
    从不属于 release。

    .OUTPUTS
        @{ Ok; Error; Extracted }
#>
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
        没有压缩包时使用的单个 winst.ps1（从当前运行脚本引导）。
        此时 winst.cmd 会在本地生成。

    .OUTPUTS
        @{ Ok; Error; Extracted }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [string]$ArchivePath = '',
        [string]$SourceDir = '',
        [string]$FallbackSourcePath = ''
    )

    $result = @{ Ok = $false; Error = ''; Extracted = $false }

    $staging = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-self-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

    # 树从哪来，仅用于报错文案。调用方传的是已解压的 SourceDir 时
    # ArchivePath 可能为空。
    $sourceLabel = $ArchivePath
    if (-not $sourceLabel) { $sourceLabel = $SourceDir }
    if (-not $sourceLabel) { $sourceLabel = $FallbackSourcePath }

    try {
        if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $InstallDir -Force -ErrorAction Stop
        }

        $null = New-Item -ItemType Directory -Path $staging -Force -ErrorAction Stop

        # ---------------------------------------------------------- 取得树
        if ($SourceDir -and (Test-Path -LiteralPath $SourceDir -PathType Container)) {
            # 调用方已经解压过：直接复制树，不再把同一个压缩包解一遍。
            foreach ($item in @(Get-ChildItem -LiteralPath $SourceDir -Force -ErrorAction Stop)) {
                Copy-Item -LiteralPath $item.FullName -Destination (Join-WinstPath $staging $item.Name) -Recurse -Force -ErrorAction Stop
            }
            $result.Extracted = $true
        } elseif ($ArchivePath -and (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
            $expand = Expand-WinstPackageArchive -Context $null -ArchivePath $ArchivePath -DestDir $staging
            if (-not $expand.Ok) {
                $result.Error = ('解压 winst 安装包失败：{0}' -f $expand.Error)
                return $result
            }
            $result.Extracted = $true
        } elseif ($FallbackSourcePath -and (Test-Path -LiteralPath $FallbackSourcePath -PathType Leaf)) {
            # 引导场景：只有一个脚本可用。铺一个最小树并在本地生成启动器。
            Copy-Item -LiteralPath $FallbackSourcePath -Destination (Join-WinstPath $staging 'winst.ps1') -Force -ErrorAction Stop
            $result.Extracted = $false
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

        # 真正的 release 带可运行的模块，引导场景没有，
        # 因此只在来源是 release 压缩包时才要求它。
        $stagedModules = Join-WinstPath $staging 'Modules'
        if ($result.Extracted) {
            if (-not (Test-Path -LiteralPath $stagedModules -PathType Container)) {
                $result.Error = ('winst 安装包里没有 Modules 目录（来源: {0}）' -f $sourceLabel)
                return $result
            }
            $stagedManifests = @(Get-ChildItem -LiteralPath $stagedModules -Recurse -Filter '*.psd1' -File -ErrorAction Stop)
            if ($stagedManifests.Count -eq 0) {
                $result.Error = ('winst 安装包的 Modules 目录里没有模块清单（来源: {0}）' -f $sourceLabel)
                return $result
            }
            $stagedItems = @(Get-ChildItem -LiteralPath $stagedModules -Recurse -Force -ErrorAction Stop)
            if ((Test-WinstReparsePoint -Path $stagedModules) -or
                @($stagedItems | Where-Object { Test-WinstReparsePoint -Path $_.FullName }).Count -gt 0) {
                $result.Error = ('winst 安装包的 Modules 目录含有重解析点（来源: {0}）' -f $sourceLabel)
                return $result
            }
        }

        # release 的 Modules 必须整棵替换，不能合并出嵌套目录或留下旧模块。
        if ($result.Extracted) {
            $targetModules = Join-WinstPath $InstallDir 'Modules'
            if (Test-Path -LiteralPath $targetModules) {
                Clear-WinstInstallDir -Dir $targetModules
                if (Test-Path -LiteralPath $targetModules) {
                    $result.Error = ('无法安全替换 Modules 目录: {0}' -f $targetModules)
                    return $result
                }
            }
        }

        # ------------------------------------------- 清理目标目录的过期条目
        $userDataNames = @('lists')
        if (-not $result.Extracted) { $userDataNames += 'Modules' }

        foreach ($item in @(Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue)) {
            $name = $item.Name

            # 保留用户数据。
            if ($userDataNames -contains $name) { continue }
            if ($item.PSIsContainer -eq $false -and $item.Extension -ieq '.list') { continue }

            # 保留 release 即将提供的条目（下面的合并会覆盖它们）。
            $stagedChild = Join-WinstPath $staging $name
            if (Test-Path -LiteralPath $stagedChild) { continue }

            if ($item.PSIsContainer) {
                Clear-WinstInstallDir -Dir $item.FullName
            } else {
                Remove-Item -LiteralPath $item.FullName -Force -ErrorAction SilentlyContinue
            }
        }

        # ------------------------------------------------------------- 合并
        foreach ($item in @(Get-ChildItem -LiteralPath $staging -Force -ErrorAction SilentlyContinue)) {
            $target = Join-WinstPath $InstallDir $item.Name

            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $item.FullName -Destination $target -Recurse -Force -ErrorAction Stop
                continue
            }

            Copy-Item -LiteralPath $item.FullName -Destination $target -Force -ErrorAction Stop
        }

        # ---------------------------------------------------- 启动器兜底
        # 仅单文件引导路径需要。release 自带 winst.cmd，
        # 不能被生成的版本覆盖。
        $launcherPath = Join-WinstPath $InstallDir 'winst.cmd'
        if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
            $null = New-WinstScriptLauncher -ScriptPath (Join-WinstPath $InstallDir 'winst.ps1')
        }

        # ------------------------------------------------------------ 校验
        if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
            $result.Error = ('安装后没有找到启动器: {0}' -f $launcherPath)
            return $result
        }

        $installedScript = Join-WinstPath $InstallDir 'winst.ps1'
        if (-not (Test-Path -LiteralPath $installedScript -PathType Leaf)) {
            $result.Error = ('安装后没有找到 winst.ps1: {0}' -f $installedScript)
            return $result
        }

        if ($result.Extracted) {
            $installedModules = Join-WinstPath $InstallDir 'Modules'
            $stagedItems = @(Get-ChildItem -LiteralPath $stagedModules -Recurse -Force -ErrorAction Stop)
            $installedItems = @(Get-ChildItem -LiteralPath $installedModules -Recurse -Force -ErrorAction Stop)
            $stagedNames = @($stagedItems | ForEach-Object {
                    ($_.FullName.Substring($stagedModules.Length).TrimStart('\', '/') + $(if ($_.PSIsContainer) { '\' } else { '' }))
                } | Sort-Object)
            $installedNames = @($installedItems | ForEach-Object {
                    ($_.FullName.Substring($installedModules.Length).TrimStart('\', '/') + $(if ($_.PSIsContainer) { '\' } else { '' }))
                } | Sort-Object)
            if (($stagedNames -join "`n") -cne ($installedNames -join "`n")) {
                $result.Error = ('安装后的 Modules 目录与安装包不一致: {0}' -f $installedModules)
                return $result
            }
            foreach ($item in @($stagedItems | Where-Object { -not $_.PSIsContainer })) {
                $relative = $item.FullName.Substring($stagedModules.Length).TrimStart('\', '/')
                $installedItem = Join-WinstPath $installedModules $relative
                $stagedHash = Get-WinstFileHash -Path $item.FullName -Algorithm SHA256
                $installedHash = Get-WinstFileHash -Path $installedItem -Algorithm SHA256
                if ($item.Length -ne (Get-Item -LiteralPath $installedItem -Force -ErrorAction Stop).Length -or
                    -not $stagedHash -or $stagedHash -cne $installedHash) {
                    $result.Error = ('安装后的模块文件与安装包不一致: {0}' -f $installedItem)
                    return $result
                }
            }
        }

        $result.Ok = $true
        return $result
    } catch {
        $result.Error = ('展开 winst 安装包失败：{0}' -f $_.Exception.Message)
        return $result
    } finally {
        try {
            if (Test-Path -LiteralPath $staging) { Clear-WinstInstallDir -Dir $staging }
        } catch { }
    }
}
