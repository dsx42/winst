#Requires -Version 5.1

function Get-WinstPackageDirectoryMap {
    <#
    .SYNOPSIS
        扫描安装包位置下实际含文件的 id 目录，返回路径、文件、大小及格式化大小。
    #>
    param([string]$PkgDir)

    $map = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    if (-not $PkgDir -or -not (Test-Path -LiteralPath $PkgDir -PathType Container)) { return $map }
    foreach ($dir in @(Get-ChildItem -LiteralPath $PkgDir -Directory -ErrorAction SilentlyContinue)) {
        if ($dir.Name -ieq 'manifests') { continue }
        $names = New-Object 'System.Collections.Generic.List[string]'
        $size = [long]0
        foreach ($file in @(Get-ChildItem -LiteralPath $dir.FullName -File -ErrorAction SilentlyContinue)) {
            $names.Add([string]$file.Name)
            $size += [long]$file.Length
        }
        if ($names.Count -eq 0) { continue }
        $map[[string]$dir.Name] = [ordered]@{
            Path      = [string]$dir.FullName
            Files     = @($names.ToArray())
            SizeBytes = $size
            SizeText  = (Format-WinstSizeText -Bytes $size)
        }
    }
    return $map
}
