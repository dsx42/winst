#Requires -Version 5.1

function Get-WinstPackageDirectoryMap {
    <#
    .SYNOPSIS
        扫描安装包位置下含正式文件的 id 目录；缓存列表也包含仍有下载暂存目录的软件。
    #>
    param([string]$PkgDir, [string[]]$Ids, [switch]$IncludeDownloadStage)

    $map = New-WinstOrdinalDictionary
    if (-not $PkgDir -or -not (Test-Path -LiteralPath $PkgDir -PathType Container)) { return $map }
    $dirs = if ($PSBoundParameters.ContainsKey('Ids')) {
        foreach ($id in $Ids) {
            if (-not (Test-WinstSafePathSegment -Name $id)) { continue }
            foreach ($dir in @(Get-ChildItem -LiteralPath $PkgDir -Filter $id -Directory -ErrorAction SilentlyContinue)) {
                if ($dir.Name -ceq $id) { $dir }
            }
        }
    } else { Get-ChildItem -LiteralPath $PkgDir -Directory -ErrorAction SilentlyContinue }
    foreach ($dir in $dirs) {
        if (Test-WinstReservedPackageId -Id $dir.Name) { continue }
        $size = [long]0
        $names = @(foreach ($file in @(Get-ChildItem -LiteralPath $dir.FullName -File -ErrorAction SilentlyContinue)) {
            [string]$file.Name
            $size += [long]$file.Length
        })
        $hasStage = $IncludeDownloadStage -and (Test-Path -LiteralPath (Join-WinstPath $dir.FullName 'winst-download') -PathType Container)
        if ($names.Count -eq 0 -and -not $hasStage) { continue }
        $map[[string]$dir.Name] = [ordered]@{
            Path      = [string]$dir.FullName
            HasDownloadStage = $hasStage
            Files     = $names
            SizeBytes = $size
        }
    }
    return $map
}
