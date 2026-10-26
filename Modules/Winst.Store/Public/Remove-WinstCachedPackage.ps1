#Requires -Version 5.1

function Remove-WinstCachedPackage {
    <#
    .SYNOPSIS
        删除某软件的全部已下载安装包（缓存目录 + 缓存索引条目），等同 `winst clean <id>`。
    .DESCRIPTION
        删除的是该 id 在安装包位置下的整个目录（主包 + 配套文件），
        并同步移除缓存索引里的条目；`--dry-run` 下只报告将删除的内容、不动盘。
        `-PackageNoun`：调用方知道条目是「仅下载」类型时传 `软件包`，文案随之改口径。
    .OUTPUTS
        @{ Ok; Message; Error; Path; FileCount; Files; DryRun }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$PackageNoun = '安装包'
    )

    if (-not $PackageNoun) { $PackageNoun = '安装包' }

    $result = @{ Ok = $false; Message = ''; Error = ''; Path = ''; FileCount = 0; Files = @(); DryRun = $false }

    if (-not $Context.PkgDir) { $result.Error = '没有可用的安装包位置。'; return $result }
    if (-not $Id) { $result.Error = '缺少软件 id。'; return $result }

    # id 直接拼成 <pkgDir>\<id> 并整目录删除：`winst clean ..\资料` 这类输入必须在这里挡住，
    # 否则会跳出安装包位置删掉任意目录（Clear-WinstInstallDir 的黑名单挡不住任意父目录）
    if (-not (Test-WinstSafePathSegment -Name $Id)) {
        $result.Error = ('软件 id 不合法（只能是单个目录名，且不能是 . / .. 或含非法字符）：{0}' -f $Id)
        return $result
    }

    $dir = Join-WinstPath $Context.PkgDir $Id
    if (-not (Test-WinstPathUnderRoot -Path $dir -Root $Context.PkgDir)) {
        $result.Error = ('软件 id 指向安装包位置之外，已拒绝：{0}' -f $Id)
        return $result
    }
    $result.Path = $dir

    $fileList = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path -LiteralPath $dir -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) { $fileList.Add([string]$file.Name) }
    }
    $files = $fileList.ToArray()
    $result.FileCount = $files.Count
    $result.Files = @($files)
    if ($files.Count -eq 0) {
        $result.Error = ('没有找到「{0}」的已下载{1}。' -f $Id, $PackageNoun)
        return $result
    }

    if ([bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)) {
        $result.DryRun = $true
        $result.Ok = $true
        $result.Message = ('（预览）将删除「{0}」的 {1} 个已下载{2}文件: {3}' -f $Id, $files.Count, $PackageNoun, $dir)
        return $result
    }

    Clear-WinstInstallDir -Dir $dir -AllowedRoot $Context.PkgDir
    if (Test-Path -LiteralPath $dir -PathType Container) {
        $remain = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)
        if ($remain.Count -gt 0) {
            $result.Error = ('部分{0}文件未能删除，请手动检查: {1}' -f $PackageNoun, $dir)
            return $result
        }
        $left = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
        if ($left.Count -eq 0) { try { [IO.Directory]::Delete($dir, $false) } catch { } }
    }

    # 同步缓存索引（索引键可能与该 id 仅大小写不同，一并移除）；写失败不影响已完成的删除，
    # 下次读取索引时该条目会因目录已不存在而自动清除。
    $indexNote = ''
    try {
        $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
        $index = $cacheRead.Index
        foreach ($key in @($index.Keys)) {
            if ([string]$key -ieq $Id) { $index.Remove($key) }
        }
        Save-WinstCacheIndex -PkgDir $Context.PkgDir -Index $index
    } catch {
        $indexNote = ('（安装包索引未能更新，下次会自动校正）')
    }

    $result.Ok = $true
    $result.Message = ('已删除「{0}」的已下载{1}: {2} 个文件{3}' -f $Id, $PackageNoun, $files.Count, $indexNote)
    return $result
}
