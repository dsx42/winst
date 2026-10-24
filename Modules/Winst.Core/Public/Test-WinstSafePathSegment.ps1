#Requires -Version 5.1

function Test-WinstSafePathSegment {
    <#
    .SYNOPSIS
        判断一个名称能否安全地作为单层目录 / 文件名拼到指定目录下。
    .DESCRIPTION
        清单里的 id 与文件名会被直接 Join-Path 到安装目录 / 缓存目录，安装（清理模式）还会递归删除该目录：
        名称里带目录分隔符、`.` / `..`、驱动器号或非法字符时，拼出来的路径会跑到目标目录之外。
        先查非法字符（已含 `\` `/` `:` 等）再比 `.` / `..`，最后确认 GetFileName 原样返回——
        `GetFileName` 对部分非法字符会抛异常，因此不能单独用它做校验。

        除分隔符外还必须挡住 Win32 归一化带来的等价写法：
          - 尾点 / 尾空格：`.. `、`name.` 在 Win32 层会被折叠成 `..` / `name`，校验时看着无害、落地后越界；
          - 保留设备名：`CON`、`NUL`、`COM1` 加任意后缀仍是设备；
          - 控制字符与超长名：会让后续路径拼接 / 删除报错或产生意外截断。
    .OUTPUTS
        [bool]
    #>
    param(
        [string]$Name,
        [int]$MaxLength = 100
    )

    if (-not $Name) { return $false }
    $text = [string]$Name
    if ($text.Length -gt $MaxLength) { return $false }
    if ($text -ne $text.Trim()) { return $false }
    if ($text.EndsWith('.')) { return $false }
    if ($text -match '[\x00-\x1F]') { return $false }
    if ($text.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) { return $false }
    if ($text -eq '.' -or $text -eq '..') { return $false }
    if ($text -ne [IO.Path]::GetFileName($text)) { return $false }
    if (Test-WinstReservedDeviceName -Name $text) { return $false }
    return $true
}
