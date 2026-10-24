#Requires -Version 5.1

function Remove-WinstStaleCompanionFiles {
    <#
    .SYNOPSIS
        删除「上次落位、这次不需要」的配套文件。
    .OUTPUTS
        @{ Removed; KeptDirs }——Removed = 实际删除的相对路径（用于提示删了什么）；
        KeptDirs = 保留未删的目录（extract 型配套文件的 dest，调用方提示用户自行清理）
    .DESCRIPTION
        只删安装目录内的东西（dest 已在清单层校验，这里再兜一层越界检查）；已经不存在的项直接跳过。
        **目录不整棵删**：声明 extract 的配套文件在 appliedFiles 里记的是 dest 目录，而目录里可能还有
        主包解压出的或用户自己放进去的文件——整棵删除是不可逆的数据破坏，因此保留并回报，
        由调用方给一行提示（宁可留一点残留，也不误删用户的东西）。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$InstallDir,
        $PreviousFiles,
        $CurrentFiles
    )

    $result = @{ Removed = @(); KeptDirs = @() }
    if (-not $InstallDir) { return $result }

    $current = @()
    foreach ($item in @($CurrentFiles)) {
        $text = ([string]$item).Trim()
        if ($text) { $current += $text.ToLowerInvariant().Replace('/', '\').TrimEnd('\') }
    }

    $rootFull = ''
    try { $rootFull = ([IO.Path]::GetFullPath($InstallDir)).TrimEnd('\') } catch { $rootFull = '' }

    foreach ($item in @($PreviousFiles)) {
        $text = ([string]$item).Trim()
        if (-not $text) { continue }
        $normalized = $text.ToLowerInvariant().Replace('/', '\').TrimEnd('\')
        if ($current -contains $normalized) { continue }
        $path = Join-Path $InstallDir $text
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $full = ''
        try { $full = [IO.Path]::GetFullPath($path) } catch { $full = '' }
        if (-not $full -or -not $rootFull -or -not $full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) { continue }

        $isDir = $false
        try { $isDir = [bool](Get-Item -LiteralPath $full -Force).PSIsContainer } catch { $isDir = $false }
        if ($isDir) {
            # 目录（extract 型配套文件的 dest）不整棵删：里面可能还有主包解压出的或用户自己放的文件，
            # 误删不可逆 —— 保留并回报，由调用方提示用户自行清理
            $result.KeptDirs += $text
            continue
        }

        try {
            Remove-Item -LiteralPath $full -Force -ErrorAction Stop
            $result.Removed += $text
        } catch {
            # 删不掉（被占用 / 权限不足）不阻断更新，下一次仍会尝试
        }
    }
    return $result
}
