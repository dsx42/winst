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
        @{ Ok; Message; Error; FailureKind; Path; FileCount; Files; DryRun }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$PackageNoun = '安装包'
    )

    if (-not $PackageNoun) { $PackageNoun = '安装包' }

    $result = @{ Ok = $false; Message = ''; Error = ''; FailureKind = 'Parameter'; Path = ''; FileCount = 0; Files = @(); DryRun = $false }

    if (-not $Context.PkgDir) { $result.Error = '没有可用的安装包位置。'; return $result }
    if (-not $Id) { $result.Error = '缺少软件 id。'; return $result }

    # id 直接拼成 <pkgDir>\<id> 并整目录删除：`winst clean ..\资料` 这类输入必须在这里挡住，
    # 否则会跳出安装包位置删掉任意目录（Clear-WinstInstallDir 的黑名单挡不住任意父目录）
    if (-not (Test-WinstSafePathSegment -Name $Id) -or (Test-WinstReservedPackageId -Id $Id)) {
        $result.Error = ('软件 id 不合法（只能是单个目录名，且不能是 . / .. 或含非法字符）：{0}' -f $Id)
        return $result
    }

    if ($Context.PkgDir -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+)') { $result.Error = '安装包位置必须为绝对路径。'; return $result }
    try { $dir = Join-WinstPath ([IO.Path]::GetFullPath($Context.PkgDir)) $Id }
    catch { $result.Error = $_.Exception.Message; return $result }
    if (-not (Test-WinstPathUnderRoot -Path $dir -Root $Context.PkgDir)) {
        $result.Error = ('软件 id 指向安装包位置之外，已拒绝：{0}' -f $Id)
        return $result
    }
    $result.Path = $dir
    try {
        $result.FailureKind = 'Execution'
        Assert-WinstSafeWritePath -Path $dir -Directory

        $fileList = New-Object 'System.Collections.Generic.List[string]'
        if (Test-Path -LiteralPath $dir -PathType Container) {
            foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop)) { $fileList.Add([string]$file.Name) }
        }
        $files = $fileList.ToArray()
        $result.FileCount = $files.Count
        $result.Files = @($files)
        $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
        if (-not $cacheRead.CanSave) { $result.Error = $cacheRead.Error; return $result }
        if ($files.Count -eq 0 -and -not $cacheRead.Index.Contains($Id)) {
            $result.FailureKind = 'Parameter'
            $result.Error = ('没有找到「{0}」的已下载{1}。' -f $Id, $PackageNoun)
            return $result
        }

        if ([bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)) {
            $result.DryRun = $true
            $result.Ok = $true
            $result.FailureKind = ''
            $result.Message = ('（预览）将删除「{0}」的 {1} 个已下载{2}文件: {3}' -f $Id, $files.Count, $PackageNoun, $dir)
            return $result
        }

        Clear-WinstInstallDir -Dir $dir -AllowedRoot $Context.PkgDir -Strict
        if (Test-Path -LiteralPath $dir -PathType Container) {
            $remain = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop)
            if ($remain.Count -gt 0) {
                $result.Error = ('部分{0}文件未能删除，请手动检查: {1}' -f $PackageNoun, $dir)
                return $result
            }
            try { [IO.Directory]::Delete($dir, $false) } catch { $result.Error = $_.Exception.Message; return $result }
        }

        # 索引按精确 id 删除；写回失败仍向调用方报告。
        try {
            Save-WinstCacheIndex -PkgDir $Context.PkgDir -Update {
                param($index)
                foreach ($key in @($index.Keys)) {
                    if ([string]$key -ceq $Id) { $index.Remove($key) }
                }
            }
        } catch {
            $result.Error = ('文件已删除，但安装包索引更新失败：{0}' -f $_.Exception.Message)
            return $result
        }

        $result.Ok = $true
        $result.FailureKind = ''
        $result.Message = ('已删除「{0}」的已下载{1}: {2} 个文件' -f $Id, $PackageNoun, $files.Count)
    } catch { $result.Error = $_.Exception.Message }
    return $result
}
