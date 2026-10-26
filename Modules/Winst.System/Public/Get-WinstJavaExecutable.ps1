#Requires -Version 5.1

function Get-WinstJavaExecutable {
    <#
    .SYNOPSIS
        找一个可用的 java.exe，用于「程序是 jar、要由 java 启动」的版本探测（如 PlantUML）。
    .DESCRIPTION
        查找顺序：%JAVA_HOME%\bin\java.exe → 安装根目录下的 jdk*\bin\java.exe（winst 刚装好的 JDK，
        新开的窗口才有 PATH，这里兜住「同一进程里接着用」的场景）→ PATH 上的 java.exe。
        找不到返回空串，由调用方报出「需要 java」的提示。
    #>
    param([hashtable]$Context = $null)

    $candidates = @()
    $javaHome = ''
    try { $javaHome = [string]$env:JAVA_HOME } catch { $javaHome = '' }
    if ($javaHome) { $candidates += (Join-WinstPath $javaHome 'bin\java.exe') }
    if ($Context) {
        $root = [string]$Context.InstallRoot
        if ($root) { $candidates += (Join-WinstPath $root 'jdk*\bin\java.exe') }
    }

    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        try {
            $hits = @(Get-Item -Path $candidate -Force -ErrorAction SilentlyContinue)
            if ($hits.Count -gt 0) { return [string]$hits[0].FullName }
        } catch { }
    }

    $command = $null
    try { $command = Get-Command 'java.exe' -ErrorAction SilentlyContinue } catch { $command = $null }
    if ($command) {
        $source = ''
        try { $source = [string]$command.Source } catch { $source = '' }
        if (-not $source) {
            try { $source = [string]$command.Path } catch { $source = '' }
        }
        if ($source -and (Test-Path -LiteralPath $source -PathType Leaf)) { return $source }
    }
    return ''
}
