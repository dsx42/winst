#Requires -Version 5.1

function Get-Winst7zEntryPaths {
    <#
    .SYNOPSIS
        列出压缩包里的条目路径（`7z l -slt` 技术列表：解析 `Path =` 行，跳过目录与压缩包自身的元信息块）。
    .OUTPUTS
        @{ Ok; Paths; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SevenZip,
        [Parameter(Mandatory = $true)][string]$ArchivePath
    )

    $result = @{ Ok = $false; Paths = @(); Error = '' }
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        $result.Error = ('压缩包不存在: {0}' -f $ArchivePath)
        return $result
    }

    $output = $null
    try {
        $output = @(& $SevenZip l -slt $ArchivePath 2>&1)
    } catch {
        $result.Error = ('列不出压缩包内容（{0}）' -f $_.Exception.Message)
        return $result
    }
    $exitCode = $LASTEXITCODE
    if ($exitCode -notin @(0, 1)) {
        # 7z 退出码：0 成功 / 1 警告（列表仍可用）/ 2 起为致命错误
        $detail = ''
        foreach ($line in @($output)) { $text = [string]$line; if ($text.Trim()) { $detail = $text.Trim(); break } }
        $result.Error = ('列不出压缩包内容（7z 退出码 {0}{1}）' -f $exitCode, $(if ($detail) { ': ' + $detail } else { '' }))
        return $result
    }

    $paths = @()
    $current = ''
    $isDir = $false
    $hasAttrs = $false
    foreach ($line in @($output)) {
        $text = [string]$line
        if ($text -match '^Path\s*=\s*(.+)\s*$') {
            if ($current -and -not $isDir -and $hasAttrs) { $paths += $current }
            $current = $Matches[1].Trim()
            $isDir = $false
            $hasAttrs = $false
            continue
        }
        if ($text -match '^Folder\s*=\s*(.+)\s*$') {
            $isDir = ($Matches[1].Trim() -eq '+')
            $hasAttrs = $true
            continue
        }
        if ($text -match '^Attributes\s*=') {
            $hasAttrs = $true
            # Attributes 里的 D 标记 = 目录（如「D_ drwxrwxrwx」）
            if ($text -match '^Attributes\s*=\s*\S*D') { $isDir = $true }
            continue
        }
    }
    if ($current -and -not $isDir -and $hasAttrs) { $paths += $current }
    $result.Ok = $true
    $result.Paths = @($paths)
    return $result
}
