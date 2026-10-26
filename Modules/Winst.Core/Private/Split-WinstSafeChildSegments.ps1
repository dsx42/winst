#Requires -Version 5.1

function Split-WinstSafeChildSegments {
    <#
    .SYNOPSIS
        把「包内相对路径 / 相对模式」逐段校验并拼到根目录下；路径与通配两种用法的公共实现。
    .DESCRIPTION
        清单里的 stripTopDir / extractFiles / postInstallCopy / installerExe 等字段会被 Join-WinstPath 到
        临时解压目录或安装目录：`..\..\Windows\System32` 能直接跳出根目录、把任意位置的内容搬进安装目录
        （或反过来写到系统目录）。这里是**唯一一处**做这个校验的地方：

          1. 拒绝绝对路径、盘符、UNC 路径；
          2. 逐段拒绝 `..`，`.` 与空段跳过（`./foo` 等价于 `foo`）；
          3. 每段交给 Test-WinstSafePathSegment（非法字符 / 保留设备名 / 尾点尾空格 / 超长）；
          4. 拼好后用 Test-WinstPathUnderRoot 复核仍在根目录下。

        -AllowWildcard 供「只允许 `*` / `?` 的相对模式」使用（postInstallCopy.from / installerExe）：
        额外拒绝控制字符与 `[` `]`（PowerShell 其它通配语法）。.NET Framework 的 GetFullPath 拒绝
        `*` / `?`，因此边界复核改用「把通配符替换成 x」的同结构普通路径（返回的 ProbePath）。
    .OUTPUTS
        @{ Ok; Path; ProbePath; Error }
        Path  = 实际要用的路径（保留通配符）
        ProbePath = 用于边界复核的普通路径（无通配符时与 Path 相同）
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Child,
        [string]$Label = '路径',
        [switch]$AllowWildcard
    )

    $result = @{ Ok = $false; Path = ''; ProbePath = ''; Error = '' }
    if (-not $Root) { $result.Error = ('{0}：缺少根目录' -f $Label); return $result }

    $text = ([string]$Child).Trim()
    if (-not $text) { $result.Error = ('{0}为空' -f $Label); return $result }
    if ([IO.Path]::IsPathRooted($text) -or $text -match '^[A-Za-z]:' -or $text.StartsWith('\\')) {
        $result.Error = ('{0}不能是绝对路径或网络路径：{1}' -f $Label, $Child)
        return $result
    }
    if ($AllowWildcard -and ($text -match '[\x00-\x1F\[\]]')) {
        $result.Error = ('{0}含有不支持的字符：{1}' -f $Label, $Child)
        return $result
    }

    $segments = New-Object 'System.Collections.Generic.List[string]'
    $probeSegments = New-Object 'System.Collections.Generic.List[string]'
    foreach ($segment in ($text -split '[\\/]')) {
        $one = [string]$segment
        if (-not $one -or $one -eq '.') { continue }
        if ($one -eq '..') {
            $result.Error = ('{0}不能包含上级目录（..）：{1}' -f $Label, $Child)
            return $result
        }
        # Test-WinstSafePathSegment 不接受通配符；替换成普通字符后复用其余 Win32 名称校验
        $probe = $one
        if ($AllowWildcard) { $probe = $one.Replace('*', 'x').Replace('?', 'x') }
        if (-not (Test-WinstSafePathSegment -Name $probe)) {
            $result.Error = ('{0}里有不合法的名称「{1}」：{2}' -f $Label, $one, $Child)
            return $result
        }
        $segments.Add($one)
        $probeSegments.Add($probe)
    }
    if ($segments.Count -eq 0) { $result.Error = ('{0}为空' -f $Label); return $result }

    $sep = [string][IO.Path]::DirectorySeparatorChar
    $full = Join-WinstPath $Root ([string]::Join($sep, $segments.ToArray()))
    $probeFull = $full
    if ($AllowWildcard) { $probeFull = Join-WinstPath $Root ([string]::Join($sep, $probeSegments.ToArray())) }
    if (-not (Test-WinstPathUnderRoot -Path $probeFull -Root $Root)) {
        $result.Error = ('{0}会落到目标目录之外：{1}' -f $Label, $Child)
        return $result
    }

    $result.Ok = $true
    $result.Path = $full
    $result.ProbePath = $probeFull
    return $result
}
