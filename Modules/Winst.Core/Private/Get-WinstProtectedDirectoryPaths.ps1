#Requires -Version 5.1

function Get-WinstProtectedDirectoryPaths {
    <#
    .SYNOPSIS
        缓存当前账号的实际关键目录与禁止清理的系统子树。
    #>
    $signature = '{0}|{1}|{2}' -f $env:SystemRoot, $env:USERPROFILE, $env:ProgramData
    $cached = Get-WinstState -Name WinstProtectedDirectoryPaths
    if ($cached -and $cached.Signature -ceq $signature) { return $cached }

    $exact = New-Object 'System.Collections.Generic.List[string]'
    $trees = New-Object 'System.Collections.Generic.List[string]'
    $paths = @($env:SystemRoot, $env:WINDIR, $env:USERPROFILE, $env:ProgramData,
        $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:CommonProgramFiles, ${env:CommonProgramFiles(x86)})
    foreach ($folder in [Enum]::GetValues([Environment+SpecialFolder])) {
        # 可虚拟化的系统目录返回空字符串；只保护实际文件系统路径。
        $value = [Environment]::GetFolderPath($folder)
        if ($value) { $paths += $value }
    }
    foreach ($path in $paths) {
        if (-not $path) { continue }
        try { $exact.Add([IO.Path]::GetFullPath($path).TrimEnd('\', '/')) } catch { }
    }
    foreach ($path in @($env:SystemRoot, $env:WINDIR)) {
        if ($path) { $trees.Add([IO.Path]::GetFullPath($path).TrimEnd('\', '/')) }
    }
    $result = @{ Signature = $signature; Exact = $exact.ToArray(); Trees = $trees.ToArray() }
    $null = Set-WinstState -Name WinstProtectedDirectoryPaths -Value $result
    return $result
}
