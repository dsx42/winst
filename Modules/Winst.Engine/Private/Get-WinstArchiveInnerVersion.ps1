#Requires -Version 5.1

function Get-WinstArchiveInnerVersion {
    <#
    .SYNOPSIS
        按 source.packageVersion 规格用 7-Zip 读包内结构派生版本号。
    .DESCRIPTION
        流程：`7z l -slt` 列外层包 →（规格声明 inner 时）按通配取出第一个命中的内层压缩包、再列它 →
        按规格 path 通配命中第一条目路径 → 用 versionKind / versionBetween 从命中条目的**文件名**识别
        版本，未声明识别器时退「第一个像版本号的内容」。
        内层包解到进程临时目录，finally 里清理。各软件的包内结构差异全部写在清单里，本函数不含任何软件特例。
    .OUTPUTS
        @{ Ok; Version; MatchedPath; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SevenZip,
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [Parameter(Mandatory = $true)]$Spec
    )

    $result = @{ Ok = $false; Version = ''; MatchedPath = ''; Error = '' }
    $pathGlob = ([string](Get-EntryString -Entry $Spec -Key 'path')).Trim()
    if (-not $pathGlob) {
        $result.Error = 'packageVersion 规格里没有 path（最内层压缩包里的条目路径通配）'
        return $result
    }

    $workDir = Join-WinstPath ([System.IO.Path]::GetTempPath()) ('winst-pkgver-' + [guid]::NewGuid().ToString('N'))
    try {
        $null = New-Item -ItemType Directory -Path $workDir -Force -ErrorAction Stop
        $listArchive = $PackagePath
        $innerGlob = ([string](Get-EntryString -Entry $Spec -Key 'inner')).Trim()
        if ($innerGlob) {
            # 外层包里先找到内层压缩包（按文件名通配，取第一个命中），取出来才能列它的内容
            $outer = Get-Winst7zEntryPaths -SevenZip $SevenZip -ArchivePath $PackagePath
            if (-not $outer.Ok) {
                $result.Error = ('读不出安装包内容（{0}）' -f $outer.Error)
                return $result
            }
            $innerEntry = ''
            foreach ($entryPath in @($outer.Paths)) {
                $entryName = Split-Path ([string]$entryPath) -Leaf
                if ($entryName -like $innerGlob) { $innerEntry = [string]$entryPath; break }
            }
            if (-not $innerEntry) {
                $result.Error = ('安装包里没找到内层压缩包（inner: {0}）；可能是安装包结构变更，需要更新软件源的 packageVersion 配置' -f $innerGlob)
                return $result
            }
            $extractDir = Join-WinstPath $workDir 'inner'
            $null = New-Item -ItemType Directory -Path $extractDir -Force
            $null = & $SevenZip x $PackagePath $innerEntry "-o$extractDir" -y 2>&1
            if ($LASTEXITCODE -notin @(0, 1)) {
                $result.Error = ('取不出内层压缩包 {0}（7z 退出码 {1}）' -f $innerEntry, $LASTEXITCODE)
                return $result
            }
            $innerFile = Join-WinstPath $extractDir ([string]$innerEntry)
            if (-not (Test-Path -LiteralPath $innerFile -PathType Leaf)) {
                $result.Error = ('内层压缩包取出后不在预期位置: {0}' -f $innerFile)
                return $result
            }
            $listArchive = $innerFile
        }

        $entries = Get-Winst7zEntryPaths -SevenZip $SevenZip -ArchivePath $listArchive
        if (-not $entries.Ok) {
            $result.Error = ('读不出包内容（{0}）' -f $entries.Error)
            return $result
        }
        $matched = ''
        foreach ($entryPath in @($entries.Paths)) {
            if (([string]$entryPath) -like $pathGlob) { $matched = [string]$entryPath; break }
        }
        if (-not $matched) {
            $result.Error = ('包内没有命中 {0} 的条目；可能是安装包结构变更，需要更新软件源的 packageVersion 配置' -f $pathGlob)
            return $result
        }
        $result.MatchedPath = $matched

        $baseName = Split-Path $matched -Leaf
        $version = Get-WinstVersionFromText -Text $baseName `
            -Kind ([string](Get-EntryString -Entry $Spec -Key 'kind')).Trim() `
            -Between @(Get-EntryArray -Entry $Spec -Key 'between')
        if (-not $version) { $version = Get-WinstFirstVersionLike -Text $baseName }
        if (-not $version) {
            $result.Error = ('从包内条目 {0} 的文件名识别不出版本号；请给 packageVersion 配上 versionKind / versionBetween' -f $baseName)
            return $result
        }
        $result.Ok = $true
        $result.Version = ([string]$version).Trim()
        return $result
    } catch {
        $result.Error = ('读包内版本失败（{0}）' -f $_.Exception.Message)
        return $result
    } finally {
        try {
            if (Test-Path -LiteralPath $workDir) { Clear-WinstInstallDir -Dir $workDir }
        } catch { }
    }
}
