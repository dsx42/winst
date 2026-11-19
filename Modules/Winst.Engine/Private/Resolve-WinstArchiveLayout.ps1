#Requires -Version 5.1

function Resolve-WinstArchiveLayout {
    <#
    .SYNOPSIS
        定位一个交付目录，只在交付单个文件或多个选中路径时创建 .winst-layout。
    #>
    param([string]$TempRoot, $StripTopDir, [string[]]$ExtractFiles)

    if ($ExtractFiles.Count -eq 0) {
        if ($StripTopDir -is [string]) { $ExtractFiles = @($StripTopDir) }
        elseif ($StripTopDir -eq $true) {
            $top = @(Get-WinstChildItem -Path $TempRoot -ErrorAction Stop | Select-Object -First 2)
            if ($top.Count -eq 1 -and $top[0].PSIsContainer) {
                Assert-WinstSafeWritePath -Path $top[0].FullName
                return $top[0].FullName
            }
        }
        if ($ExtractFiles.Count -eq 0) { return $TempRoot }
    }

    $selected = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($one in $ExtractFiles) {
        $safe = Resolve-WinstSafeChildPath -Root $TempRoot -Child $one -Label '软件源里的解压路径'
        if (-not $safe.Ok) { throw $safe.Error }
        if (-not $seen.Add($safe.Path)) { continue }
        if (-not (Test-WinstFileSystemPath -Path $safe.Path)) { throw ('压缩包缺少所需路径：' + $one) }
        Assert-WinstSafeWritePath -Path $safe.Path
        $selected.Add($safe.Path)
    }
    if ($selected.Count -eq 1 -and (Test-WinstFileSystemPath -Path $selected[0] -PathType Container)) {
        return $selected[0]
    }
    $layout = Join-WinstPath $TempRoot '.winst-layout'
    if (Test-WinstFileSystemPath -Path $layout) {
        throw '压缩包包含布局合并保留名称 .winst-layout，无法创建工作目录'
    }
    $null = [IO.Directory]::CreateDirectory((ConvertTo-WinstExtendedPath -Path $layout))
    foreach ($path in $selected) {
        $item = Get-WinstFileSystemItem -Path $path
        if ($item.PSIsContainer) {
            Get-WinstChildItem -Path $path -ErrorAction Stop | ForEach-Object {
                Move-WinstItemInto -Source $_ -DestDir $layout
            }
        } else {
            Move-WinstItemInto -Source $item -DestDir $layout
        }
    }
    return $layout
}
