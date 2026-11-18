#Requires -Version 5.1

function Get-WinstPackageDirectorySet {
    <#
    .SYNOPSIS
        全量核对索引时一次枚举可见及隐藏目录，按 Windows 文件系统的大小写规则查找。
    #>
    param([string]$PkgDir)

    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($dir in (Get-ChildItem -LiteralPath $PkgDir -Directory -Force -ErrorAction Stop)) {
        $null = $names.Add($dir.Name)
    }
    return ,$names
}
