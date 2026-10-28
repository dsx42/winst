#Requires -Version 5.1

function Split-WinstCommandLine {
    <#
    .SYNOPSIS
        把系统安装记录里的命令行拆成「程序路径 + 参数」（去掉包裹引号）。
    .OUTPUTS
        @{ Ok; Exe; Args }
    #>
    param([string]$Text)

    $result = @{ Ok = $false; Exe = ''; Args = '' }
    if (-not $Text) { return $result }
    $value = ([string]$Text).Trim()
    if (-not $value) { return $result }

    if ($value.StartsWith('"')) {
        $end = $value.IndexOf('"', 1)
        if ($end -gt 1) {
            $result.Exe = $value.Substring(1, $end - 1)
            $result.Args = $value.Substring($end + 1).Trim()
            $result.Ok = $true
            return $result
        }
    }

    # 只认「后面紧跟空白或行尾」的 .exe：参数里带引号的 .exe（regsvr32 /s "C:\x.exe"）
    # 与路径中间的 .exe.d 目录都不该算作程序部分
    $exeMatch = [regex]::Match($value, '(?i)\.exe(?=\s|$)')
    if ($exeMatch.Success) {
        $result.Exe = $value.Substring(0, $exeMatch.Index + 4).Trim()
        $result.Args = $value.Substring($exeMatch.Index + 4).Trim()
        $result.Ok = $true
        return $result
    }

    $spaceIndex = $value.IndexOf(' ')
    if ($spaceIndex -gt 0) {
        $result.Exe = $value.Substring(0, $spaceIndex).Trim()
        $result.Args = $value.Substring($spaceIndex + 1).Trim()
        $result.Ok = $true
        return $result
    }

    $result.Exe = $value
    $result.Ok = $true
    return $result
}
