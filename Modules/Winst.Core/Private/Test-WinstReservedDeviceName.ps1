#Requires -Version 5.1

function Test-WinstReservedDeviceName {
    <#
    .SYNOPSIS
        判断名称是否是 Windows 保留设备名（CON / NUL / COM1 / LPT1 等）。
    .DESCRIPTION
        `CON.list`、`NUL.zip` 这类名字在 Win32 层仍被解析成设备而不是文件：GetFileName 不报错、
        非法字符检查也不命中，但写入后会落在设备上（失败或挂起）。因此按「点号前的词干」判定。
    .OUTPUTS
        [bool]
    #>
    param([string]$Name)

    if (-not $Name) { return $false }
    $stem = ([string]$Name).Trim()
    $dot = $stem.IndexOf('.')
    if ($dot -ge 0) { $stem = $stem.Substring(0, $dot) }
    $stem = $stem.Trim().ToUpperInvariant()
    if (-not $stem) { return $false }
    if (@('CON', 'PRN', 'AUX', 'NUL', 'CONIN$', 'CONOUT$') -contains $stem) { return $true }
    if ($stem -match '^(COM|LPT)[1-9]$') { return $true }
    return $false
}
