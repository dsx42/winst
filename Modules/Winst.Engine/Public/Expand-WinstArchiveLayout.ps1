#Requires -Version 5.1

function Expand-WinstArchiveLayout {
    <#
    .SYNOPSIS
        按清单的 stripTopDir / extractFiles 设置把压缩包内容解压到目标目录（先解压到临时目录，再按需挑拣）。
    .DESCRIPTION
        stripTopDir：$true = 压缩包仅含单一顶层目录时剥掉；$false = 原样解压；
        字符串 = 只取压缩包内该相对路径（目录 = 该目录下的内容；文件 = 该文件本身，文件本身是压缩包时
        递归解压其内容，见 Test-WinstArchiveFileByExtension）（不存在即报错）。
        extractFiles（字符串数组）= 只取包内这几个相对路径（文件或目录，语义同上面的字符串形式，可写多个）；
        声明了它就以它为准、不看 stripTopDir——引擎包用这种方式"只从官方 7-Zip 安装包里取 7z.exe + 7z.dll"
        ；缺哪个路径即报错，不静默少装。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestDir,
        $StripTopDir = $true,
        [string[]]$ExtractFiles = @()
    )

    $result = @{ Ok = $false; Error = '' }
    $tempRoot = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-x-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

    try {
        $null = New-Item -ItemType Directory -Path $tempRoot -Force -ErrorAction Stop

        $expand = Expand-WinstPackageArchive -Context $Context -ArchivePath $ArchivePath -DestDir $tempRoot
        if (-not $expand.Ok) { $result.Error = $expand.Error; return $result }

        # extractFiles：只搬这几个路径（文件 / 目录），一个都不能少
        # 每一项都先过 Resolve-WinstSafeChildPath：`..\..\Windows\System32` 这类写法能从临时解压目录
        # 跳到任意位置，把外面目录里的内容搬进安装目录
        $wanted = New-Object 'System.Collections.Generic.List[string]'
        $wantedPaths = New-Object 'System.Collections.Generic.List[string]'
        foreach ($one in @($ExtractFiles)) {
            $text = ([string]$one).Trim()
            if (-not $text) { continue }
            $safeChild = Resolve-WinstSafeChildPath -Root $tempRoot -Child $text -Label '软件源里的解压路径'
            if (-not $safeChild.Ok) { $result.Error = $safeChild.Error; return $result }
            $wanted.Add($text)
            $wantedPaths.Add([string]$safeChild.Path)
        }
        if ($wanted.Count -gt 0) {
            if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
                $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
            }
            $missing = New-Object 'System.Collections.Generic.List[string]'
            $wantedItems = $wanted.ToArray()
            $wantedFullPaths = $wantedPaths.ToArray()
            for ($wi = 0; $wi -lt $wantedItems.Length; $wi++) {
                $sub = $wantedItems[$wi]
                $candidate = $wantedFullPaths[$wi]
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    # 文件 = 该文件本身；Move-WinstItemInto 要文件系统对象，不能传路径字符串
                    Move-WinstItemInto -Source (Get-Item -LiteralPath $candidate -Force) -DestDir $DestDir
                    continue
                }
                if (Test-Path -LiteralPath $candidate -PathType Container) {
                    # 目录 = 该目录下的内容（不保留目录名本身），与 stripTopDir 的字符串形式同一口径
                    foreach ($item in @(Get-ChildItem -LiteralPath $candidate -Force -ErrorAction SilentlyContinue)) {
                        Move-WinstItemInto -Source $item -DestDir $DestDir
                    }
                    continue
                }
                $missing.Add($sub)
            }
            if ($missing.Count -gt 0) {
                $result.Error = ('压缩包里没有「{0}」，无法按软件源的设置解压' -f ($missing.ToArray() -join '、'))
                return $result
            }
            $result.Ok = $true
            return $result
        }

        $sourceDir = $tempRoot
        if ($StripTopDir -is [string]) {
            # 与 extractFiles 同一道闸：只允许临时解压目录内的相对路径
            $safeStrip = Resolve-WinstSafeChildPath -Root $tempRoot -Child ([string]$StripTopDir) -Label '软件源里的解压路径'
            if (-not $safeStrip.Ok) {
                $result.Error = $safeStrip.Error
                return $result
            }
            $candidate = [string]$safeStrip.Path
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                # 字符串也可以指向包内的一个文件：只把这一个文件解压出来；
                # 该文件本身又是压缩包时（按扩展名识别，如 OpenCode 桌面版的 NSIS 安装器 → $PLUGINSDIR\app-64.7z）
                # 解压其内容到目标目录
                if (Test-WinstArchiveFileByExtension -Path $candidate) {
                    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
                        $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
                    }
                    $inner = Expand-WinstPackageArchive -Context $Context -ArchivePath $candidate -DestDir $DestDir
                    if (-not $inner.Ok) { $result.Error = $inner.Error; return $result }
                    $result.Ok = $true
                    return $result
                }
                if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
                    $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
                }
                # Move-WinstItemInto 要的是文件系统对象（Name / FullName / PSIsContainer），不能直接传路径字符串
                Move-WinstItemInto -Source (Get-Item -LiteralPath $candidate -Force) -DestDir $DestDir
                $result.Ok = $true
                return $result
            }
            if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
                $result.Error = ('压缩包里没有「{0}」这个文件或目录，无法按软件源的设置解压' -f $StripTopDir)
                return $result
            }
            $sourceDir = $candidate
        } elseif ($StripTopDir -eq $true) {
            $top = @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue)
            if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $sourceDir = $top[0].FullName }
        }

        if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
        }
        foreach ($item in @(Get-ChildItem -LiteralPath $sourceDir -Force -ErrorAction SilentlyContinue)) {
            Move-WinstItemInto -Source $item -DestDir $DestDir
        }
        $result.Ok = $true
        return $result
    } catch {
        $result.Error = ('解压失败：{0}' -f $_.Exception.Message)
        return $result
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Clear-WinstInstallDir -Dir $tempRoot }
    }
}
