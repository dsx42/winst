#Requires -Version 5.1

function Expand-WinstArchiveLayout {
    <#
    .SYNOPSIS
        按清单的 stripTopDir / extractFiles 设置把压缩包内容解压到目标目录（先解压到临时目录，再按需挑拣）。
    .DESCRIPTION
        stripTopDir：$true = 压缩包仅含单一顶层目录时剥掉；$false = 原样解压；
        字符串 = 只取压缩包内该相对路径（目录 = 该目录下的内容；文件 = 该文件本身，文件本身是压缩包时
        递归解压其内容，见 Test-WinstArchiveFileByExtension）（不存在即报错）。
        extractFiles（字符串数组）= 只取包内这几个相对路径（文件取自身、目录取内容；不会自动展开内层压缩文件，可写多个）；
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
        [string[]]$ExtractFiles = @(),
        # 允许「切出 7-Zip 自解压包的内嵌载荷」：只在安装 7-Zip-CLI 时由调用方传
        [switch]$AllowSfxPayload
    )

    $result = @{ Ok = $false; Error = '' }
    $tempRoot = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-x-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

    try {
        Assert-WinstSafeWritePath -Path $DestDir -Directory
        Assert-WinstSafeWritePath -Path $tempRoot -Directory
        $null = New-Item -ItemType Directory -Path $tempRoot -Force -ErrorAction Stop

        $expand = Expand-WinstPackageArchive -Context $Context -ArchivePath $ArchivePath -DestDir $tempRoot -AllowSfxPayload:$AllowSfxPayload
        if (-not $expand.Ok) { $result.Error = $expand.Error; return $result }

        # 先校验完整解压树，再选择目录；不能先枚举 junction 的目标。
        Assert-WinstTreeWithoutReparsePoint -Path $tempRoot

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
            $missing = @($wantedPaths | Where-Object { -not (Test-Path -LiteralPath $_) })
            if ($missing.Count -gt 0) {
                $result.Error = ('压缩包缺少所需路径：{0}' -f ($missing -join '、'))
                return $result
            }
            foreach ($candidate in $wantedPaths) {
                $moved = Move-WinstArchiveSelection -Context $Context -Path $candidate -DestDir $DestDir
                if (-not $moved.Ok) { $result.Error = $moved.Error; return $result }
            }
            $result.Ok = $true
            return $result
        }

        $sourceDir = $tempRoot
        if ($StripTopDir -is [string]) {
            $safe = Resolve-WinstSafeChildPath -Root $tempRoot -Child $StripTopDir -Label '软件源里的解压路径'
            if (-not $safe.Ok) { $result.Error = $safe.Error; return $result }
            $sourceDir = $safe.Path
            if (-not (Test-Path -LiteralPath $sourceDir)) {
                $result.Error = ('压缩包里没有所需路径：{0}' -f $StripTopDir)
                return $result
            }
        } elseif ($StripTopDir -eq $true) {
            $top = @(Get-ChildItem -LiteralPath $tempRoot -Force -ErrorAction Stop)
            if ($top.Count -eq 1 -and $top[0].PSIsContainer) { $sourceDir = $top[0].FullName }
        }
        $moved = Move-WinstArchiveSelection -Context $Context -Path $sourceDir -DestDir $DestDir `
            -ExpandInner:($StripTopDir -is [string]) -AllowSfxPayload:$AllowSfxPayload
        if (-not $moved.Ok) { $result.Error = $moved.Error; return $result }
        $result.Ok = $true
        return $result
    } catch {
        $result.Error = ('解压失败：{0}' -f $_.Exception.Message)
        return $result
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Clear-WinstInstallDir -Dir $tempRoot }
    }
}
