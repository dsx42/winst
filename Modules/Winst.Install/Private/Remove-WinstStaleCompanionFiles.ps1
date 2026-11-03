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

    $result = @{ Removed = @(); KeptDirs = @(); Notes = @() }
    if (-not $InstallDir) { return $result }

    $current = @()
    foreach ($item in @($CurrentFiles)) {
        $text = ([string]$item).Trim()
        if ($text) { $current += $text.ToLowerInvariant().Replace('/', '\').TrimEnd('\') }
    }

    foreach ($item in @($PreviousFiles)) {
        $text = ([string]$item).Trim()
        if (-not $text) { continue }
        $normalized = $text.ToLowerInvariant().Replace('/', '\').TrimEnd('\')
        if ($current -contains $normalized) { continue }
        $safe = Resolve-WinstSafeChildPath -Root $InstallDir -Child $text -Label '旧附加文件路径'
        if (-not $safe.Ok) { $result.Notes += [string]$safe.Error; continue }
        $full = [string]$safe.Path
        try { Assert-WinstSafeWritePath -Path $full } catch {
            $result.Notes += ('旧附加文件已保留：{0}（{1}）' -f $text, $_.Exception.Message)
            continue
        }
        if (-not (Test-Path -LiteralPath $full)) { continue }

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
            $result.Notes += ('旧附加文件删除失败：{0}（{1}）' -f $text, $_.Exception.Message)
        }
    }
    return $result
}
