#Requires -Version 5.1

function Get-WinstPackageDirectoryMap {
    <#
    .SYNOPSIS
        扫描安装包位置下实际含文件的 id 目录，返回路径、文件和字节数。
    #>
    param([string]$PkgDir, [string[]]$Ids)

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
        if ($names.Count -eq 0) { continue }
        $map[[string]$dir.Name] = [ordered]@{
            Path      = [string]$dir.FullName
            Files     = $names
            SizeBytes = $size
        }
    }
    return $map
}
