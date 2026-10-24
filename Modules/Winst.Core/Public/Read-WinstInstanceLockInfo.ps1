#Requires -Version 5.1

function Read-WinstInstanceLockInfo {
    <#
    .SYNOPSIS
        读取锁文件里记录的占用者信息（只读方式打开，不抢锁）。
    .DESCRIPTION
        锁已不存在、内容被清空或格式不认识时返回空字段，由调用方决定怎么提示：
        拿不到占用者信息不影响「已有 winst 在运行」这个结论。
    .OUTPUTS
        @{ Pid; StartedAt; Path }
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $info = @{ Pid = 0; StartedAt = ''; Path = '' }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $info }

    $text = ''
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::UTF8)
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        } finally {
            $stream.Dispose()
        }
    } catch {
        return $info
    }

    foreach ($line in @($text -split "`r?`n")) {
        $one = [string]$line
        if (-not $one) { continue }
        $index = $one.IndexOf('=')
        if ($index -le 0) { continue }
        $key = $one.Substring(0, $index).Trim()
        $value = $one.Substring($index + 1).Trim()
        if ($key -ieq 'pid') {
            $parsed = 0
            if ([int]::TryParse($value, [ref]$parsed)) { $info.Pid = $parsed }
        } elseif ($key -ieq 'startedAt') {
            $info.StartedAt = $value
        } elseif ($key -ieq 'path') {
            $info.Path = $value
        }
    }
    return $info
}
